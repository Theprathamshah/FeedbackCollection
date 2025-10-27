
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";
import { PrismaClient } from "@prisma/client";

const secretsClient = new SecretsManagerClient({ region: "ap-south-1" });

async function getDbUrl() {
    const command = new GetSecretValueCommand({ SecretId: "feedback-app/db-credentials" });
    const response = await secretsClient.send(command);

    if (!response.SecretString) {
        throw new Error("SecretString is empty");
    }

    const creds = JSON.parse(response.SecretString);

    return `postgresql://${creds.username}:${creds.password}@${creds.host}:${creds.port}/${creds.dbname}`;
}

export async function getPrismaClient() {
    const dbUrl = await getDbUrl();
    return new PrismaClient({
        datasources: {
            db: {
                url: dbUrl,
            },
        },
    });
}
