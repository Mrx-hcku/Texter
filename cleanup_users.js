// cleanup_users.js
// Deletes documents in the "users" collection whose Auth account no
// longer exists (i.e. was deleted from Auth without cleaning up the
// matching database document).
// Run with: node cleanup_users.js

const ENDPOINT = "https://sgp.cloud.appwrite.io/v1";
const PROJECT_ID = "6a8e7ddd00107e2b7857";
const API_KEY = "YAHAN_APNI_API_KEY_DAALO";
const DB_ID = "messgram_db";

const headers = {
  "X-Appwrite-Project": PROJECT_ID,
  "X-Appwrite-Key": API_KEY,
  "Content-Type": "application/json",
};

async function listAuthUsers() {
  const res = await fetch(`${ENDPOINT}/users?queries[]=limit(100)`, { headers });
  const data = await res.json();
  if (!data.users) {
    console.error("Failed to list Auth users:", JSON.stringify(data));
    return [];
  }
  return data.users;
}

async function listUserDocs() {
  const res = await fetch(`${ENDPOINT}/databases/${DB_ID}/collections/users/documents?queries[]=limit(100)`, { headers });
  const data = await res.json();
  if (!data.documents) {
    console.error("Failed to list user documents:", JSON.stringify(data));
    return [];
  }
  return data.documents;
}

async function deleteDoc(id) {
  const res = await fetch(`${ENDPOINT}/databases/${DB_ID}/collections/users/documents/${id}`, {
    method: "DELETE",
    headers,
  });
  if (res.status === 204) {
    console.log(`  Deleted orphaned doc: ${id}`);
  } else {
    const out = await res.json().catch(() => ({}));
    console.error(`  ! Failed to delete ${id}:`, out.message || res.status);
  }
}

async function main() {
  console.log("Fetching Auth users...");
  const authUsers = await listAuthUsers();
  const authIds = new Set(authUsers.map((u) => u.$id));
  console.log(`Found ${authIds.size} real Auth accounts.`);

  console.log("Fetching user documents...");
  const docs = await listUserDocs();
  console.log(`Found ${docs.length} documents in the users collection.`);

  const orphans = docs.filter((d) => !authIds.has(d.$id));
  console.log(`Found ${orphans.length} orphaned documents (no matching Auth account).`);

  for (const doc of orphans) {
    console.log(`Deleting orphan: ${doc.name || doc.email || doc.$id}`);
    await deleteDoc(doc.$id);
  }

  console.log("\nDone! Remaining real accounts:");
  const remaining = docs.filter((d) => authIds.has(d.$id));
  remaining.forEach((d) => console.log(`  - ${d.name} (${d.email})`));
}

main().catch((e) => console.error(e));
