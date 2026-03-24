/**
 * Copyright 2021-present, Facebook, Inc. All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

"use strict";

const redis = require('redis');
const config = require('./config');

let isRedisAvailable = false;

const client = redis.createClient({
  socket: {
    host: config.redisHost,
    port: config.redisPort,
    // Disable automatic reconnect loops when Redis isn't running.
    reconnectStrategy: () => false
  }
});

client.on('error', (err) => {
  if (!isRedisAvailable) {
    console.warn('Redis unavailable, running without cache.');
    console.warn(err.message);
  }
});

client.connect()
  .then(() => {
    isRedisAvailable = true;
  })
  .catch(() => {
    isRedisAvailable = false;
  });

module.exports = class Cache {
    static async insert(key) {
        if (!isRedisAvailable) {
          return;
        }

        /**
         * As of when this was written, the redis client doesn't support
         * setting a TTL on members of the set dataytype. Instead, we'll
         * use the standard hash map with a dummy value to mimic one.
        */
        await client.set(key, "");

        // Assume that most "delivered / read" webhooks will happen within
        // 15 seconds.
        await client.expire(key, 15);
    }

    static async remove(key) {
        if (!isRedisAvailable) {
          return false;
        }

        let resp = await client.del(key);

        /**
         * Optionally, your application can measure / report the ingress latency
         * from Cloud API webhooks via Redis's TTL.
         * Ex.
         *      someLoggingFunc(client.ttl(key));
        */

        return resp > 0;
    }
}
