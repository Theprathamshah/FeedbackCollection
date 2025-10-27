// import { PrismaClient } from '../../generated/prisma';
// import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

// declare global {
//   // Prevent multiple instances of Prisma in dev (hot-reload safe)
//   // eslint-disable-next-line no-var
//   var prisma: PrismaClient | undefined;
//   var dbCredentials: DbCredentials | undefined;
// }

// interface DbCredentials {
//   username: string;
//   password: string;
//   host: string;
//   port: number;
//   dbname: string;
// }

// const secretsManager = new SecretsManagerClient({ region: "ap-south-1" });
// const SECRET_ID = "feedback-app/db-credentials";

// let prisma: PrismaClient | undefined;

// /**
//  * Fetch and cache database credentials from Secrets Manager
//  */
// async function getDbCredentials(): Promise<DbCredentials> {
//   if (global.dbCredentials) {
//     return global.dbCredentials;
//   }

//   const response = await secretsManager.send(
//     new GetSecretValueCommand({ SecretId: SECRET_ID })
//   );

//   if (!response.SecretString) {
//     throw new Error(`❌ No secret value found in Secrets Manager for ${SECRET_ID}`);
//   }

//   const creds = JSON.parse(response.SecretString) as DbCredentials;
//   global.dbCredentials = creds;
//   return creds;
// }

// /**
//  * Initialize Prisma Client with secrets
//  */

// export async function initDatabase(): Promise<PrismaClient> {
//   if (!prisma) {
//     const creds = await getDbCredentials();
//     console.log(creds)
//     // Normalize host field
//     const host: string = creds.host || process.env.DATABASE_URL || "";
//     const port: number = creds.port ? Number(creds.port) : 5432;

//     if (!host) {
//       throw new Error("❌ Database host not found in Secrets Manager JSON");
//     }

//     // Build DATABASE_URL
//     process.env.DATABASE_URL = `postgresql://${encodeURIComponent(
//       creds.username
//     )}:${encodeURIComponent(creds.password)}@${host}:${port}/${creds.dbname}`;
//     console.log(process.env.DATABASE_URL)
//     // Initialize Prisma
//     const client = new PrismaClient({
//       log: process.env.NODE_ENV === "development"
//         ? ["query", "info", "warn", "error"]
//         : ["error"],
//     });

//     if (process.env.NODE_ENV === "production") {
//       prisma = client;
//     } else {
//       if (!global.prisma) {
//         global.prisma = client;
//       }
//       prisma = global.prisma;
//     }

//     console.log("✅ Prisma initialized with RDS connection");
//   }

//   return prisma!;
// }


// /**
//  * Graceful shutdown
//  */
// const gracefulShutdown = async (signal: string): Promise<void> => {
//   console.log(`Received ${signal}. Disconnecting from database...`);
//   await prisma?.$disconnect();
//   process.exit(0);
// };

// process.on('beforeExit', async () => {
//   console.log('Disconnecting from database...');
//   await prisma?.$disconnect();
// });

// process.on('SIGINT', () => gracefulShutdown('SIGINT'));
// process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

// /**
//  * Public connect function
//  */
// export const connectToDatabase = async (): Promise<void> => {
//   const client = await initDatabase();
//   try {
//     await client.$connect();
//     console.log('✅ Connected to database successfully');
//   } catch (error) {
//     console.error('❌ Failed to connect to database:', error);
//     throw error;
//   }
// };

// /**
//  * Health check for DB
//  */
// export const isDatabaseHealthy = async (): Promise<boolean> => {
//   const client = await initDatabase();
//   try {
//     await client.$queryRaw`SELECT 1`;
//     return true;
//   } catch (error) {
//     console.error('❌ Database health check failed:', error);
//     return false;
//   }
// };

// export default prisma;

// src/lib/db.ts
import { PrismaClient } from '../../generated/prisma';
import 'dotenv/config';

declare global {
  // Prevent multiple instances of Prisma in dev
  // eslint-disable-next-line no-var
  var prisma: PrismaClient | undefined;
}

// Construct your database URL
const DATABASE_URL = `postgresql://${encodeURIComponent(
  process.env.DB_USER || 'feedback_admin'
)}:${encodeURIComponent(
  process.env.DB_PASSWORD || 'SuperSecret123'
)}@${process.env.DB_HOST || 'feedback-postgres-db.c46rjksfsmdo.ap-south-1.rds.amazonaws.com'}:${process.env.DB_PORT || 5432}/${process.env.DB_NAME || 'feedbackdb'}?schema=public`;

// Initialize Prisma Client
const prisma: PrismaClient = global.prisma || new PrismaClient({
  datasources: { db: { url: DATABASE_URL } },
  log: process.env.NODE_ENV === 'development' ? ['query', 'info', 'warn', 'error'] : ['error'],
});

// Attach to global in dev to prevent multiple instances
if (process.env.NODE_ENV !== 'production') global.prisma = prisma;

console.log('✅ Prisma initialized with RDS connection');

/**
 * Graceful shutdown
 */
const gracefulShutdown = async (signal: string) => {
  console.log(`Received ${signal}. Disconnecting from database...`);
  await prisma.$disconnect();
  process.exit(0);
};

process.on('beforeExit', async () => {
  console.log('Disconnecting from database...');
  await prisma.$disconnect();
});
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

/**
 * Connect helper
 */
export const connectToDatabase = async () => {
  try {
    await prisma.$connect();
    console.log('✅ Connected to database successfully');
  } catch (error) {
    console.error('❌ Failed to connect to database:', error);
    throw error;
  }
};

/**
 * Health check
 */
export const isDatabaseHealthy = async (): Promise<boolean> => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return true;
  } catch (error) {
    console.error('❌ Database health check failed:', error);
    return false;
  }
};

export default prisma;
