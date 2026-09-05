const ENDPOINT = "https://sgp.cloud.appwrite.io/v1";
const PROJECT_ID = "6a8e7ddd00107e2b7857";
const API_KEY = "standard_1cb837fff0e2f2dab01068a16778100a859e388788aa30b3c603f2c030050f93a94982763dc50b4badeacdcb6c800044f23e48712f0edb11819206107ca2aaff321e4de9265652ea737a013cb195592d96a483e642056d052e0f4c7f98801592eb53f969a26ff3a57d01ae7d08a04e736b1b7e21a1e05160f61110c984313041";
const DB_ID = "messgram_db";

const headers = {
  "X-Appwrite-Project": PROJECT_ID,
  "X-Appwrite-Key": API_KEY,
  "Content-Type": "application/json",
};

async function listAll(collectionId) {
  const res = await fetch(`${ENDPOINT}/databases/${DB_ID}/collections/${collectionId}/documents?limit=100`, { headers });
  const data = await res.json();
  if (!data.documents) {
    console.error(`Failed to list ${collectionId}:`, JSON.stringify(data));
    return [];
  }
  return data.documents;
}

async function updateDoc(collectionId, id, payloadData) {
  const res = await fetch(`${ENDPOINT}/databases/${DB_ID}/collections/${collectionId}/documents/${id}`, {
    method: "PATCH",
    headers,
    body: JSON.stringify({ data: payloadData }),
  });
  const out = await res.json();
  if (out.code) console.error(`  ! update ${collectionId}/${id} failed:`, out.message);
  return out;
}

async function main() {
  console.log("Fetching existing users...");
  const users = await listAll("users");
  const existingIds = new Set(users.map((u) => u.$id));
  console.log(`Found ${existingIds.size} existing users.`);

  console.log("\nCleaning groups...");
  const groups = await listAll("groups");
  for (const g of groups) {
    const members = (g.memberIds || []).filter((id) => existingIds.has(id));
    const admins = (g.adminIds || []).filter((id) => existingIds.has(id));
    const changed =
      members.length !== (g.memberIds || []).length ||
      admins.length !== (g.adminIds || []).length;
    if (changed) {
      console.log(`  Cleaning group "${g.name}" (${g.$id}): ${g.memberIds.length} -> ${members.length} members`);
      await updateDoc("groups", g.$id, { memberIds: members, adminIds: admins });
    }
  }

  console.log("\nCleaning channels...");
  const channels = await listAll("channels");
  for (const c of channels) {
    const subs = (c.subscriberIds || []).filter((id) => existingIds.has(id));
    if (subs.length !== (c.subscriberIds || []).length) {
      console.log(`  Cleaning channel "${c.name}" (${c.$id}): ${c.subscriberIds.length} -> ${subs.length} subscribers`);
      await updateDoc("channels", c.$id, { subscriberIds: subs, subscriberCount: subs.length });
    }
  }

  console.log("\nCleaning direct chats...");
  const chats = await listAll("chats");
  for (const c of chats) {
    const participants = (c.participantIds || []).filter((id) => existingIds.has(id));
    if (participants.length !== (c.participantIds || []).length) {
      console.log(`  Cleaning chat "${c.name || c.$id}": ${c.participantIds.length} -> ${participants.length} participants`);
      await updateDoc("chats", c.$id, { participantIds: participants });
    }
  }

  console.log("\nDone!");
}

main().catch((e) => console.error(e));
