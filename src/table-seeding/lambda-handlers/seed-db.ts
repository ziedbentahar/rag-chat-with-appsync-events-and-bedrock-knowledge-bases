import {
    RDSDataClient,
    ExecuteStatementCommand,
    CommitTransactionCommand,
    RollbackTransactionCommand,
    BeginTransactionCommand,
} from "@aws-sdk/client-rds-data";
import { SecretsManagerClient, PutSecretValueCommand } from "@aws-sdk/client-secrets-manager";
import { randomBytes } from "crypto";

const rdsDataClient = new RDSDataClient({ region: process.env.AWS_REGION });
const secretsManagerClient = new SecretsManagerClient({ region: process.env.AWS_REGION });

const databaseArn = process.env.DB_ARN!;
const databaseSecretArn = process.env.DB_SECRET_ARN!;
const databaseName = process.env.DB_NAME!;
const kbCredsSecretArn = process.env.KB_CREDS_SECRET_ARN!;

export const handler = async (_: unknown): Promise<void> => {
    const bedrockKnowledgeBaseCreds = {
        username: "bedrock_user",
        password: generatePostgresPassword(),
    };

    let schema = "knowledge_base";
    let vectorTable = "bedrock_kb";

    const queries = [
        `CREATE EXTENSION IF NOT EXISTS vector`,
        `CREATE SCHEMA IF NOT EXISTS ${schema}`,
        `CREATE ROLE ${bedrockKnowledgeBaseCreds.username} WITH PASSWORD '${bedrockKnowledgeBaseCreds.password}' LOGIN`,
        `GRANT ALL ON SCHEMA ${schema} to ${bedrockKnowledgeBaseCreds.username}`,
        `CREATE TABLE IF NOT EXISTS ${schema}.${vectorTable} (id uuid PRIMARY KEY, embedding vector(1024), chunks text, metadata json, custom_metadata jsonb)`,
        `CREATE INDEX IF NOT EXISTS bedrock_kb_embedding_idx ON ${schema}.${vectorTable} USING hnsw (embedding vector_cosine_ops) WITH (ef_construction=256)`,
        `CREATE INDEX IF NOT EXISTS bedrock_kb_chunks_fts_idx ON ${schema}.${vectorTable} USING gin (to_tsvector('simple', chunks))`,
        `CREATE INDEX IF NOT EXISTS bedrock_kb_custom_metadata_idx ON ${schema}.${vectorTable} USING gin (custom_metadata)`,
        `GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ${schema} TO ${bedrockKnowledgeBaseCreds.username}`,
        // `ALTER DEFAULT PRIVILEGES IN SCHEMA ${schema}
        //  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${bedrockKnowledgeBaseCreds.username}`,
    ];

    await executeTransaction(databaseArn, databaseSecretArn, databaseName, queries, bedrockKnowledgeBaseCreds);
};

const generatePostgresPassword = (length = 20) => {
    return randomBytes(length)
        .toString("base64")
        .replace(/[^a-zA-Z0-9]/g, "")
        .slice(0, length);
};

const executeTransaction = async (
    resourceArn: string,
    secretArn: string,
    database: string,
    queries: string[],
    bedrockKnowledgeBaseCreds: { username: string; password: string }
) => {
    const beginTxParams = {
        resourceArn,
        secretArn,
        database,
    };
    const beginTransactionCommand = new BeginTransactionCommand(beginTxParams);
    const transactionResponse = await rdsDataClient.send(beginTransactionCommand);
    const transactionId = transactionResponse.transactionId!;
    try {
        for (const query of queries) {
            const params = {
                resourceArn,
                secretArn,
                database,
                sql: query,
                transactionId,
            };

            const command = new ExecuteStatementCommand(params);
            await rdsDataClient.send(command);
        }

        await secretsManagerClient.send(
            new PutSecretValueCommand({
                SecretId: kbCredsSecretArn,
                SecretString: JSON.stringify(bedrockKnowledgeBaseCreds),
            })
        );
        const commitTransactionCommand = new CommitTransactionCommand({
            resourceArn,
            secretArn,
            transactionId,
        });
        await rdsDataClient.send(commitTransactionCommand);
    } catch (error) {
        const rollbackTxParams = {
            resourceArn,
            secretArn,
            transactionId,
        };
        const rollbackTransactionCommand = new RollbackTransactionCommand(rollbackTxParams);
        await rdsDataClient.send(rollbackTransactionCommand);
        console.error("Transaction rolled back.");
        console.error(error);
    }
};
