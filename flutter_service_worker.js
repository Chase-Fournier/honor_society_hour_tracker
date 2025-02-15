'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {".git/COMMIT_EDITMSG": "45b758a4f518f3ff31363696132f5f5a",
".git/config": "05712dff17d6a6d2f43b0810f26f4436",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/HEAD": "cf7dd3ce51958c5f13fece957cc417fb",
".git/hooks/applypatch-msg.sample": "ce562e08d8098926a3862fc6e7905199",
".git/hooks/commit-msg.sample": "579a3c1e12a1e74a98169175fb913012",
".git/hooks/fsmonitor-watchman.sample": "a0b2633a2c8e97501610bd3f73da66fc",
".git/hooks/post-update.sample": "2b7ea5cee3c49ff53d41e00785eb974c",
".git/hooks/pre-applypatch.sample": "054f9ffb8bfe04a599751cc757226dda",
".git/hooks/pre-commit.sample": "305eadbbcd6f6d2567e033ad12aabbc4",
".git/hooks/pre-merge-commit.sample": "39cb268e2a85d436b9eb6f47614c3cbc",
".git/hooks/pre-push.sample": "2c642152299a94e05ea26eae11993b13",
".git/hooks/pre-rebase.sample": "56e45f2bcbc8226d2b4200f7c46371bf",
".git/hooks/pre-receive.sample": "2ad18ec82c20af7b5926ed9cea6aeedd",
".git/hooks/prepare-commit-msg.sample": "2b5c047bdb474555e1787db32b2d2fc5",
".git/hooks/push-to-checkout.sample": "c7ab00c7784efeadad3ae9b228d4b4db",
".git/hooks/update.sample": "647ae13c682f7827c22f5fc08a03674e",
".git/index": "b5182d70b42d270bc19e22d9ffd161bd",
".git/info/exclude": "036208b4a1ab4a235d75c181e685e5a3",
".git/logs/HEAD": "99967aa4f1778eef5325356fbf31daed",
".git/logs/refs/heads/main": "99967aa4f1778eef5325356fbf31daed",
".git/logs/refs/remotes/origin/main": "91baed0b2a219b22eb99421181673974",
".git/objects/07/2d7c098201e41d19249b8c9366c38be5d3a43e": "8ffff375df5a870ef76e66301c8d9830",
".git/objects/0f/c344c7e8b9e32ea1ad91f30ded22556352d7bf": "a8a30f28869f7378465338066f34d80d",
".git/objects/17/9c4837191c02a77d0de7175e0cbe5181bb5d30": "2c62acba17677a842b2ef3a9a535225f",
".git/objects/18/eb401097242a0ec205d5f8abd29a4c5e09c5a3": "4e08af90d04a082aab5eee741258a1dc",
".git/objects/20/1afe538261bd7f9a38bed0524669398070d046": "82a4d6c731c1d8cdc48bce3ab3c11172",
".git/objects/20/cb2f80169bf29d673844d2bb6a73bc04f3bfb8": "b807949265987310dc442dc3f9f492a2",
".git/objects/2a/a8987d138a0144d8b3c5ca657ff85258be4bb4": "18775bc7c57a091ea833a0d19fc47ea7",
".git/objects/32/ff7362fad60dcab4eefe223b988eff09e62ea2": "293bff1ec8684b2dc0b3a41182fbeb20",
".git/objects/34/037fc8f8633a8a2057fd6f69932838862d1e93": "8b7c3905f1134f3f0c42063b03c20a30",
".git/objects/34/dc453079f23f64451096cd3bc62ede7e2a0359": "5aa65688ba28db17090e6baaff783c5d",
".git/objects/36/493a5cd25cd8b8c9aaa457105266a0274d4235": "267f7729ba136b8565579df4499d23ef",
".git/objects/48/cad8d46bb16849775d1284a6dc75ff1ea75058": "6eb1b04a608348b864372361332feb8b",
".git/objects/49/adebdb511c8c293b28db3f6792e5bac28cdc32": "ba6a3971e7f06834fd6ec3844372ce17",
".git/objects/52/ca42f9d698f3615c8aa5aca76cd325f6b95b91": "56f5d9bfd68813f1c6f4ae3589fee4d4",
".git/objects/58/356635d1dc89f2ed71c73cf27d5eaf97d956cd": "f61f92e39b9805320d2895056208c1b7",
".git/objects/58/b007afeab6938f7283db26299ce2de9475d842": "6c6cbea527763bb3cdff2cecfee91721",
".git/objects/59/6b87a83bd614b04091e7d75954783e40f92a2e": "cc60af9b78db3311e3c9fc0557d91653",
".git/objects/61/f99332d4250353bde6d57e6840c6c46d5cc3f2": "20cefc2de091f3b158a3ee199cf1c907",
".git/objects/62/c89ee094658c7a9465824fdb42793a64ea557b": "133cd5da638f245b079d9e9cdc29ae38",
".git/objects/68/8f28b0f073ad87e624697ca0303abcb6958866": "ddede9be3c981322cca576a9a947f833",
".git/objects/6e/ab91be8c0120b498a820d06588e97bc37ee542": "11c951b476a805c727f7c18f88992702",
".git/objects/71/3f932c591e8f661aa4a8e54c32c196262fd574": "66c6c54fbdf71902cb7321617d5fa33c",
".git/objects/72/005720d69366b41b6d0a9a65fee1efd0ea17fd": "0fabb619c9c379d003ef91a8182e26f1",
".git/objects/7c/61448f6cc63a9f140e28d204ce38aec22e2df1": "09860f9399f58ef88ad6b0665336d331",
".git/objects/7c/78f923d09cff3b87cf57c1d43e4a34bd65f6e8": "302ae7f7c851b6814bab3fde9d14917e",
".git/objects/88/cfd48dff1169879ba46840804b412fe02fefd6": "e42aaae6a4cbfbc9f6326f1fa9e3380c",
".git/objects/8a/aa46ac1ae21512746f852a42ba87e4165dfdd1": "1d8820d345e38b30de033aa4b5a23e7b",
".git/objects/90/f13085f5e46381fb3facd7737a3a1c4da16a76": "c863e915491583bc98ad3a7a137df564",
".git/objects/93/5611ee0e8f1bc2b49fb3dfe582aabf72eeb0cd": "0116d0e10f5f79fdf7b3696bf9ce1d75",
".git/objects/94/f7d06e926d627b554eb130e3c3522a941d670a": "77a772baf4c39f0a3a9e45f3e4b285bb",
".git/objects/98/f1217ef74ef2b0541dc1349e3985cea054146e": "42a9232c5d949cedd1eb3f2bf320cf57",
".git/objects/9a/f53ae51e817651cf86776997dc0d1a9baa964b": "bd2ebffcc32584259087695175325cd2",
".git/objects/9c/a2412f0ad1fba7afe50743efb449df1b0e9ad7": "3836cc7c55f3980a8ef3f556e5141329",
".git/objects/9f/c9510db1cbb83b070a79e7112f1e831b88b528": "b8ec2091b75008b4942311f2f9011cca",
".git/objects/aa/02702d371a6b39f6f8af717e5926ef88b18341": "3f3e2279360590b3f8fd3a2ca3f1cbc1",
".git/objects/b3/ebbd38f666d4ffa1a394c5de15582f9d7ca6c0": "23010709b2d5951ca2b3be3dd49f09df",
".git/objects/b6/4e7cb8d9a3359676e59a2eb76965230cce3e29": "8585ed42ac2541a3bb444e4e6a49ba32",
".git/objects/b7/49bfef07473333cf1dd31e9eed89862a5d52aa": "36b4020dca303986cad10924774fb5dc",
".git/objects/b9/2a0d854da9a8f73216c4a0ef07a0f0a44e4373": "f62d1eb7f51165e2a6d2ef1921f976f3",
".git/objects/b9/fe70af385e184fcf1ad588266b0e86d3db056d": "db02126268ba4b09095b51642b53aef5",
".git/objects/bf/cd53052cca6883274a383fda6eb4722f26646a": "2b9d2d9dbb91c170ef481eb571a2b816",
".git/objects/c9/bf8af1b92c723b589cc9afadff1013fa0a0213": "632f11e7fee6909d99ecfd9eeab30973",
".git/objects/d1/098e7588881061719e47766c43f49be0c3e38e": "f17e6af17b09b0874aa518914cfe9d8c",
".git/objects/d1/6cbc6a31b22cfab6efbd605c33748ac9caa119": "8074256bff5bb035d3143c7a467640ec",
".git/objects/d4/3532a2348cc9c26053ddb5802f0e5d4b8abc05": "3dad9b209346b1723bb2cc68e7e42a44",
".git/objects/d6/9c56691fbdb0b7efa65097c7cc1edac12a6d3e": "868ce37a3a78b0606713733248a2f579",
".git/objects/e2/2fe0cc761c6e9b11816c13d036141a9d1712f9": "dcbe5622d8288d650e98dc4fbdcbbe87",
".git/objects/eb/9b4d76e525556d5d89141648c724331630325d": "37c0954235cbe27c4d93e74fe9a578ef",
".git/objects/eb/b1cc9e6a3e0f0e9b23ebf97c27e27aa8415b15": "6b324a9861ab99d81b4724dee542218e",
".git/objects/ec/efe9c5f5ac80ae6c5a281f1c6c3ee67946d68b": "8fb229a7afd784d50ec39cf8987a2ef2",
".git/objects/f2/04823a42f2d890f945f70d88b8e2d921c6ae26": "6b47f314ffc35cf6a1ced3208ecc857d",
".git/objects/f8/1c30f003bed60d55e5c039f5c8a50370940d52": "0bf08a8a2a82bbe656d52e329515be69",
".git/objects/f8/e7d4b5716c9ee321df0b0b2a5ce65b1c1b0b9b": "f5207f639858dd2a4df0378273426d2c",
".git/objects/f9/2fe39228ef82843ca7244beb9cccea4e3fc67d": "2d23ca62132dc75e90378561ba66e80e",
".git/refs/heads/main": "719567c90c5648b38ade70daf91381f2",
".git/refs/remotes/origin/main": "719567c90c5648b38ade70daf91381f2",
"assets/AssetManifest.bin": "c0a9f61f2e3948196678e5326a0a75ec",
"assets/AssetManifest.bin.json": "84cb582db6487e0c407ca19cf62759e5",
"assets/AssetManifest.json": "2a9f7ef6508316d4c7d7828f3e41c1dd",
"assets/FontManifest.json": "94aeac1332d1708f89d82fa22f36ee72",
"assets/fonts/MaterialIcons-Regular.otf": "21464461424d1cc0db0911fe02d3c16f",
"assets/NOTICES": "41a7f7db04655eb7e16ebc41dabcb413",
"assets/packages/font_awesome_flutter/lib/fonts/fa-brands-400.ttf": "a4c5103d5d7302504349d94f4f712b2c",
"assets/packages/font_awesome_flutter/lib/fonts/fa-regular-400.ttf": "f3307f62ddff94d2cd8b103daf8d1b0f",
"assets/packages/font_awesome_flutter/lib/fonts/fa-solid-900.ttf": "04f83c01dded195a11d21c2edf643455",
"assets/packages/iconsax_flutter/fonts/FlutterIconsax.ttf": "83c878235f9c448928034fe5bcba1c8a",
"assets/packages/supabase_auth_ui/assets/logos/google_light.png": "f243a900707589f1b21af980454090bd",
"assets/packages/supabase_auth_ui/assets/logos/kakao.png": "7e156d594910fef4ae12696161c47a2f",
"assets/packages/supabase_auth_ui/assets/logos/keycloak.png": "ea74380ccc89dbc26bd0281dd46ee942",
"assets/packages/supabase_auth_ui/assets/logos/notion.png": "6b95dbedeafea10db8a51daccd7e31a4",
"assets/packages/supabase_auth_ui/assets/logos/workOS.png": "7ddd6d5a2e3b4dc4dbb1a2ee9ab8cd5b",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "738255d00768497e86aa4ca510cce1e1",
"canvaskit/canvaskit.js.symbols": "74a84c23f5ada42fe063514c587968c6",
"canvaskit/canvaskit.wasm": "9251bb81ae8464c4df3b072f84aa969b",
"canvaskit/chromium/canvaskit.js": "901bb9e28fac643b7da75ecfd3339f3f",
"canvaskit/chromium/canvaskit.js.symbols": "ee7e331f7f5bbf5ec937737542112372",
"canvaskit/chromium/canvaskit.wasm": "399e2344480862e2dfa26f12fa5891d7",
"canvaskit/skwasm.js": "5d4f9263ec93efeb022bb14a3881d240",
"canvaskit/skwasm.js.symbols": "c3c05bd50bdf59da8626bbe446ce65a3",
"canvaskit/skwasm.wasm": "4051bfc27ba29bf420d17aa0c3a98bce",
"canvaskit/skwasm.worker.js": "bfb704a6c714a75da9ef320991e88b03",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "383e55f7f3cce5be08fcf1f3881f585c",
"flutter_bootstrap.js": "604d966265571468702375470e88a164",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "2909082d42e887a4e69be9ee4c6e0ad6",
"/": "2909082d42e887a4e69be9ee4c6e0ad6",
"main.dart.js": "673bc69f93b80ef7fc51311acdeba984",
"manifest.json": "80fd13716958a16e0b7dea1d910c865a",
"splash/img/dark-1x.png": "8e0270120ebd23a25e13d8633b209c20",
"splash/img/dark-2x.png": "7df267e7cd2f64fb8fc7dda755571df4",
"splash/img/dark-3x.png": "174d4443c65b6e84bb3e246452859cde",
"splash/img/dark-4x.png": "2696cb4bab39c0291cc048dba51de1d3",
"splash/img/light-1x.png": "8e0270120ebd23a25e13d8633b209c20",
"splash/img/light-2x.png": "7df267e7cd2f64fb8fc7dda755571df4",
"splash/img/light-3x.png": "174d4443c65b6e84bb3e246452859cde",
"splash/img/light-4x.png": "2696cb4bab39c0291cc048dba51de1d3",
"version.json": "7d75cd681c9cfe9568affc7b2cca84bc"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
