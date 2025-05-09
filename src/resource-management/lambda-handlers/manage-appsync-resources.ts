import { AppSyncClient, CreateChannelNamespaceCommand, CreateDataSourceCommand } from "@aws-sdk/client-appsync";

export const handler = async (event: {
    tf: { action: string };
    apiId: string;
    dataSourceName: string;
    lambdaFunctionArn: string;
    serviceRoleArn: string;
    channelName: string;
}) => {
    if (
        event.apiId == null ||
        event.dataSourceName == null ||
        event.lambdaFunctionArn == null ||
        event.serviceRoleArn == null ||
        event.channelName == null
    ) {
        throw new Error("SourceArn, TargetArn, RoleArn and channel name are required");
    }

    if (event.tf.action === "create") {
        const client = new AppSyncClient({ region: process.env.AWS_REGION });

        const createDataSourceCommand = new CreateDataSourceCommand({
            apiId: event.apiId,
            name: event.dataSourceName,
            type: "AWS_LAMBDA",
            serviceRoleArn: event.serviceRoleArn,
            lambdaConfig: {
                lambdaFunctionArn: event.lambdaFunctionArn,
            },
        });

        await client.send(createDataSourceCommand);

        const createChannelCommand = new CreateChannelNamespaceCommand({
            apiId: event.apiId,
            name: event.channelName,
            subscribeAuthModes: [
                {
                    authType: "AMAZON_COGNITO_USER_POOLS",
                },
            ],
            publishAuthModes: [
                {
                    authType: "AMAZON_COGNITO_USER_POOLS",
                },
                {
                    authType: "AWS_IAM",
                },
            ],
            handlerConfigs: {
                onPublish: {
                    behavior: "DIRECT",
                    integration: {
                        dataSourceName: event.dataSourceName,
                        lambdaConfig: {
                            invokeType: "EVENT",
                        },
                    },
                },
                onSubscribe: {
                    behavior: "DIRECT",
                    integration: {
                        dataSourceName: event.dataSourceName,
                        lambdaConfig: {
                            invokeType: "EVENT",
                        },
                    },
                },
            },
        });

        await client.send(createChannelCommand);

        return;
    }

    if (event.tf.action === "delete") {
        return;
    }
};
