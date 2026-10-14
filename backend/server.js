import dotenv from 'dotenv';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Resolve the backend's own .env even when this file is launched from the
// Flutter project root or another working directory.
dotenv.config({ path: join(dirname(fileURLToPath(import.meta.url)), '.env') });

const [{ connectDatabase }, { default: app }] = await Promise.all([
  import('./src/config/database.js'),
  import('./src/app.js'),
]);
const port = process.env.PORT || 8081;
await connectDatabase();
app.listen(port, () => console.log(`Innovestia API listening on ${port}`));
