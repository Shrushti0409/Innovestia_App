import mongoose from 'mongoose';

const expectedDatabase = 'innovestia_app';

function databaseSelectedBy(uri) {
  const parsed = new URL(uri);
  if (!['mongodb:', 'mongodb+srv:'].includes(parsed.protocol)) {
    throw new Error('MONGODB_URI must use a MongoDB connection URI.');
  }
  const uriOption = [...parsed.searchParams].find(
    ([key]) => key.toLowerCase() === 'dbname',
  )?.[1];
  return uriOption || decodeURIComponent(parsed.pathname.replace(/^\/+/, ''));
}

export async function connectDatabase() {
  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI is required.');

  let requestedDatabase;
  try {
    requestedDatabase = databaseSelectedBy(uri);
  } catch {
    throw new Error('MONGODB_URI must be a valid MongoDB URI selecting innovestia_app.');
  }
  if (requestedDatabase !== expectedDatabase) {
    throw new Error(`MONGODB_URI must select the ${expectedDatabase} database.`);
  }

  // On Windows MongoDB database names are case-insensitive at the storage
  // layer. This existing app database was created with this canonical casing;
  // opening it using the lower-case URI alone makes MongoDB 13297 on first
  // write. Keep the required URI unchanged and select the same app database
  // using its existing on-disk casing on Windows.
  const connectionDatabase = process.platform === 'win32'
    ? 'Innovestia_app'
    : expectedDatabase;
  await mongoose.connect(uri, {dbName: connectionDatabase});
  const database = mongoose.connection.db.databaseName;
  if (database.toLowerCase() !== expectedDatabase) {
    await mongoose.disconnect();
    throw new Error(`Connected database is not ${expectedDatabase}; startup stopped.`);
  }

  const { host, port } = mongoose.connection;
  console.log(`MongoDB connected to ${database} at ${host}:${port || 'default port'}`);
}
