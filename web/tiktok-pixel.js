(function (w, d) {
  'use strict';

  if (w.__hrmStoreTikTokPixelBootstrapped) {
    return;
  }
  w.__hrmStoreTikTokPixelBootstrapped = true;

  // Keep pixel ID out of source control. Set it at runtime:
  // window.__HRMSTORE_TIKTOK_PIXEL_ID = '...';
  var PIXEL_ID = (w.__HRMSTORE_TIKTOK_PIXEL_ID || '').toString().trim();
  var NAMESPACE = 'hrmStoreTikTok';
  var skipAutoIdentify = false;

  function setupPixelQueue() {
    var t = 'ttq';
    w.TiktokAnalyticsObject = t;
    var ttq = (w[t] = w[t] || []);
    ttq.methods = [
      'page',
      'track',
      'identify',
      'instances',
      'debug',
      'on',
      'off',
      'once',
      'ready',
      'alias',
      'group',
      'enableCookie',
      'disableCookie',
      'holdConsent',
      'revokeConsent',
      'grantConsent',
    ];

    ttq.setAndDefer = function (target, method) {
      target[method] = function () {
        target.push([method].concat(Array.prototype.slice.call(arguments, 0)));
      };
    };

    for (var i = 0; i < ttq.methods.length; i += 1) {
      ttq.setAndDefer(ttq, ttq.methods[i]);
    }

    ttq.instance = function (id) {
      var instance = ttq._i[id] || [];
      for (var j = 0; j < ttq.methods.length; j += 1) {
        ttq.setAndDefer(instance, ttq.methods[j]);
      }
      return instance;
    };

    ttq.load = function (id, options) {
      var src = 'https://analytics.tiktok.com/i18n/pixel/events.js';
      var el;
      ttq._i = ttq._i || {};
      ttq._i[id] = [];
      ttq._i[id]._u = src;
      ttq._t = ttq._t || {};
      ttq._t[id] = +new Date();
      ttq._o = ttq._o || {};
      ttq._o[id] = options || {};
      el = d.createElement('script');
      el.type = 'text/javascript';
      el.async = true;
      el.src = src + '?sdkid=' + id + '&lib=' + t;
      var firstScript = d.getElementsByTagName('script')[0];
      if (firstScript && firstScript.parentNode) {
        firstScript.parentNode.insertBefore(el, firstScript);
      } else {
        d.head.appendChild(el);
      }
    };
  }

  function loadPixel() {
    if (!PIXEL_ID) {
      return;
    }
    if (!w.ttq || !w.ttq.load) {
      setupPixelQueue();
    }

    if (!w.ttq || !w.ttq._i || !w.ttq._i[PIXEL_ID]) {
      w.ttq.load(PIXEL_ID);
    }
  }

  function hasTtqMethod(method) {
    return !!(w.ttq && typeof w.ttq[method] === 'function');
  }

  function normalizeHash(value) {
    if (typeof value !== 'string') {
      return '';
    }
    var normalized = value.trim().toLowerCase();
    return normalized;
  }

  function pickHashedIdentity(inputIdentity) {
    var src = inputIdentity || w.__ttqIdentity || {};
    var payload = {};

    var email = normalizeHash(src.email);
    if (email) {
      payload.email = email;
    }

    var phone = normalizeHash(src.phone_number);
    if (phone) {
      payload.phone_number = phone;
    }

    var externalId = normalizeHash(src.external_id);
    if (externalId) {
      payload.external_id = externalId;
    }

    return payload;
  }

  function hasAnyKeys(obj) {
    return Object.keys(obj).length > 0;
  }

  function identify(identity) {
    if (!hasTtqMethod('identify')) {
      return;
    }
    var payload = pickHashedIdentity(identity);
    if (!hasAnyKeys(payload)) {
      return;
    }
    w.ttq.identify(payload);
  }

  function track(eventName, payload, identity) {
    if (!eventName || !hasTtqMethod('track')) {
      return;
    }
    if (identity) {
      identify(identity);
      skipAutoIdentify = true;
    }
    try {
      w.ttq.track(eventName, payload || {});
    } finally {
      skipAutoIdentify = false;
    }
  }

  function patchTrackWithIdentify() {
    if (!w.ttq || typeof w.ttq.track !== 'function') {
      return;
    }
    if (w.ttq.__hrmStoreTrackWrapped) {
      return;
    }

    var originalTrack = w.ttq.track;
    w.ttq.track = function () {
      if (!skipAutoIdentify) {
        identify();
      }
      return originalTrack.apply(w.ttq, arguments);
    };
    w.ttq.__hrmStoreTrackWrapped = true;
  }

  function toHex(arrayBuffer) {
    var bytes = new Uint8Array(arrayBuffer);
    var parts = [];
    for (var i = 0; i < bytes.length; i += 1) {
      parts.push(bytes[i].toString(16).padStart(2, '0'));
    }
    return parts.join('');
  }

  async function sha256(value) {
    var normalized = (value || '').toString().trim().toLowerCase();
    if (!normalized) {
      return '';
    }
    if (!w.crypto || !w.crypto.subtle || !w.TextEncoder) {
      throw new Error('Web Crypto API is not available in this browser.');
    }
    var buffer = new TextEncoder().encode(normalized);
    var digest = await w.crypto.subtle.digest('SHA-256', buffer);
    return toHex(digest);
  }

  async function hashIdentity(rawIdentity) {
    var src = rawIdentity || {};
    var hashed = {};

    if (src.email) {
      hashed.email = await sha256(src.email);
    }
    if (src.phone_number) {
      hashed.phone_number = await sha256(src.phone_number);
    }
    if (src.external_id) {
      hashed.external_id = await sha256(src.external_id);
    }

    return hashed;
  }

  async function identifyRaw(rawIdentity) {
    var hashed = await hashIdentity(rawIdentity);
    identify(hashed);
    return hashed;
  }

  var api = w[NAMESPACE] || {};
  api.pixelId = PIXEL_ID;
  api.identify = identify;
  api.track = track;
  api.sha256 = sha256;
  api.hashIdentity = hashIdentity;
  api.identifyRaw = identifyRaw;
  api.events = {
    viewContent: function (payload, identity) {
      track('ViewContent', payload, identity);
    },
    addToWishlist: function (payload, identity) {
      track('AddToWishlist', payload, identity);
    },
    search: function (payload, identity) {
      track('Search', payload, identity);
    },
    addPaymentInfo: function (payload, identity) {
      track('AddPaymentInfo', payload, identity);
    },
    addToCart: function (payload, identity) {
      track('AddToCart', payload, identity);
    },
    initiateCheckout: function (payload, identity) {
      track('InitiateCheckout', payload, identity);
    },
    placeAnOrder: function (payload, identity) {
      track('PlaceAnOrder', payload, identity);
    },
    completeRegistration: function (payload, identity) {
      track('CompleteRegistration', payload, identity);
    },
    purchase: function (payload, identity) {
      track('Purchase', payload, identity);
    },
  };

  w[NAMESPACE] = api;

  loadPixel();
  patchTrackWithIdentify();
  if (hasTtqMethod('page')) {
    w.ttq.page();
  }
})(window, document);
