import { AppSyncEventsResolver, UnauthorizedException } from "@aws-lambda-powertools/event-handler/appsync-events";
import { BedrockAgentRuntimeClient, RetrieveAndGenerateCommand } from "@aws-sdk/client-bedrock-agent-runtime";
import { HttpRequest } from "@smithy/protocol-http";
import { SignatureV4 } from "@smithy/signature-v4";
import { Sha256 } from "@aws-crypto/sha256-browser";
import { defaultProvider } from "@aws-sdk/credential-provider-node";

import type { Context } from "aws-lambda";
import { z } from "zod";

const app = new AppSyncEventsResolver();
const bedrockClient = new BedrockAgentRuntimeClient({ region: process.env.AWS_REGION });

const messageSchema = z.object({
    id: z.number(),
    sender: z.enum(["user", "bot"]),
    content: z.string(),
    type: z.enum(["chat"]).optional(),
    sessionId: z.string().optional(),
});

app.onPublish("/chat/request/*", async (payload, event) => {
    const identity = event.identity ? (event.identity as { sub: string; username: string }) : null;
    const sub = identity?.sub;

    if (!sub || (event.info.channel.segments.length != 3 && !event.info.channel.path.endsWith(`/${sub}`))) {
        throw new UnauthorizedException("You cannot publish to this channel");
    }

    const message = messageSchema.safeParse(payload);

    if (!message.success) {
        return {
            result: { text: "I don't understand what you mean, your message format seems invalid" },
            error: "Invalid message payload",
        };
    }

    const { content, sessionId } = message.data;

    const result = await bedrockClient.send(
        new RetrieveAndGenerateCommand({
            input: {
                text: content,
            },
            retrieveAndGenerateConfiguration: {
                type: "KNOWLEDGE_BASE",
                knowledgeBaseConfiguration: {
                    knowledgeBaseId: process.env.KB_ID,
                    modelArn: process.env.KB_MODEL_ARN,
                },
            },
            sessionId,
        })
    );

    const eventsEndpoint = `https://${process.env.EVENTS_API_DNS}/event`;

    const { method, headers, body } = await signRequest(eventsEndpoint, "POST", {
        channel: `/chat/responses/${sub}`,
        events: [
            JSON.stringify({
                result: result.output,
                sessionId: result.sessionId,
            }),
        ],
    });

    await fetch(eventsEndpoint, {
        method,
        headers,
        body,
    });

    return {
        processed: true,
    };
});

app.onSubscribe("/chat/responses/*", (payload) => {
    const identity = payload.identity ? (payload.identity as { sub: string; username: string }) : null;
    const sub = identity?.sub;

    if (!sub || (payload.info.channel.segments.length != 3 && !payload.info.channel.path.endsWith(`/${sub}`))) {
        throw new UnauthorizedException("You canno't subscribe to this channel");
    }
});

const signRequest = async (url: string, method: string, body?: any) => {
    const signer = new SignatureV4({
        credentials: defaultProvider(),
        region: process.env.AWS_REGION!,
        service: "appsync",
        sha256: Sha256,
    });

    const parsedUrl = new URL(url);
    const request = new HttpRequest({
        method,
        headers: {
            "Content-Type": "application/json",
            Host: parsedUrl.hostname,
        },
        hostname: parsedUrl.hostname,
        path: parsedUrl.pathname,
        body: body ? JSON.stringify(body) : undefined,
    });

    return signer.sign(request);
};

export const handler = async (event: unknown, context: Context) => app.resolve(event, context);
