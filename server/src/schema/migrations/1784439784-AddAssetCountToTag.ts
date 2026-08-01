import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await sql`ALTER TABLE "tag" ADD COLUMN "assetCount" integer NOT NULL DEFAULT 0;`.execute(db);
  await sql`UPDATE "tag" SET "assetCount" = (SELECT COUNT(*) FROM "tag_asset" WHERE "tag_asset"."tagId" = "tag"."id");`.execute(db);
}

export async function down(db: Kysely<any>): Promise<void> {
  await sql`ALTER TABLE "tag" DROP COLUMN "assetCount";`.execute(db);
}
