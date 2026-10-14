import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';
import app from '../src/app.js';
import {updateProfile} from '../src/controllers/resourceController.js';

let server;
let baseUrl;

before(async () => {
  server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  if (server) await new Promise((resolve, reject) => {
    server.close(error => error ? reject(error) : resolve());
  });
});

test('blocks excess auth attempts and returns the 15-second retry policy', async () => {
  let response;
  for (let attempt = 0; attempt < 11; attempt += 1) {
    response = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: '{}',
    });
    if (attempt < 10) assert.equal(response.status, 422);
  }

  assert.equal(response.status, 429);
  assert.equal(response.headers.get('retry-after'), '15');
  assert.deepEqual(await response.json(), {
    message: 'Too many attempts. Please try again in 15 seconds.',
  });
});

test('rejects invalid profile websites before writing to MongoDB', async () => {
  const response = {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };

  await updateProfile(
    {
      user: {id: '507f1f77bcf86cd799439011', role: 'STARTUP'},
      body: {name: 'Sample Startup', website: 'not a URL'},
    },
    response,
  );

  assert.equal(response.statusCode, 422);
  assert.equal(
    response.body.message,
    'Website must be a valid HTTP or HTTPS URL.',
  );
});
