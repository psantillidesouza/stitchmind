// StitchMind — resumo dos campos meta longos (yarn / main_color / materials)
// Gerado em 2026-07-07. Aplica em 45 aulas.
//
// COMO USAR:
// 1. Abra https://stitchmindapp.com/admin e faça login como admin
// 2. Abra o DevTools (F12) > aba Console
// 3. Cole este arquivo INTEIRO e aperte Enter
// O script busca o meta atual de cada aula, mescla os resumos por cima
// (preserva vídeo, pontos, campos legados) e salva via PATCH.

(async () => {
  const SUMMARIES = {
 "3d-puff-petal-crochet-flower-appliques-rainbow-set-mq5a8r6r": {
  "id": "92e0ea72-7d2c-4734-8c8e-4aa0ab9c33c0",
  "yarn": "#3-#4 DK/worsted acrylic, rainbow scraps",
  "main_color": "Rainbow petals, contrast centers",
  "materials": [
   "#3-#4 DK/worsted acrylic, many colors",
   "3.5-4.0 mm hook (E/G)",
   "Tapestry needle, scissors"
  ]
 },
 "amigurumi-aquarium-scene-clownfish-tropical-fish-coral-reef-in-a-bowl-mq59gdh3": {
  "id": "28cba930-9486-45c8-82f5-5f6f33014d97",
  "yarn": "#2-#3 DK/sport cotton or acrylic, multicolor",
  "main_color": "Orange clownfish, blue fish, red coral",
  "materials": [
   "#2-#3 DK/sport yarn, many bright colors",
   "2.5-3.5 mm hook",
   "Fiberfill stuffing, safety eyes",
   "Tapestry needle, stitch markers, scissors",
   "Glass bowl, gravel, driftwood, clear thread"
  ]
 },
 "autumn-granny-square-cocoon-cardigan-mq59sft0": {
  "id": "3d3ed000-9291-49ef-be17-2fcc2c9cc029",
  "yarn": "#4 worsted acrylic/wool blend, autumn tones",
  "main_color": "Maroon, gold, rust; cream joins",
  "materials": [
   "#4 worsted acrylic or wool-blend yarn",
   "Cream, mustard gold, rust, maroon",
   "4.5-5.0 mm hook (G/H)",
   "Tapestry needle, stitch markers, scissors"
  ]
 },
 "autumn-granny-square-rug-mq5ksjd1": {
  "id": "e8bdcd38-2dcc-4b44-9e83-486e99527fe4",
  "yarn": "#4-#5 chunky cotton cord or acrylic",
  "main_color": "Orange, olive, rust, cream; teal trim",
  "materials": [
   "#4-#5 chunky yarn or cotton cord",
   "Teal, rust, olive, cream, orange-gold",
   "5.0-6.0 mm hook",
   "Tapestry needle, stitch markers, scissors",
   "Optional non-slip backing"
  ]
 },
 "bear-crochet-eyeglass-holder-glasses-nest-mq9wee5b": {
  "id": "38016d32-3bac-4fb2-a207-1d3d93c46fa8",
  "yarn": "#4 worsted yarn, tan and cream",
  "main_color": "Tan/beige with cream and black",
  "materials": [
   "#4 worsted yarn: tan, cream, black",
   "Gray-brown speckle yarn (optional)",
   "4.0-4.5 mm hook",
   "Tapestry needle, stitch markers",
   "Small amount of stuffing",
   "Scissors"
  ]
 },
 "blue-daisy-chain-crochet-bracelet-mqid4ujw": {
  "id": "2e826313-3e8f-417c-964b-b48d51924f0a",
  "yarn": "Size 10 cotton thread, blue and cream",
  "main_color": "Blue flowers, cream centers",
  "materials": [
   "Size 10 cotton thread, cornflower blue",
   "Size 10 cotton thread, cream/ecru",
   "1.5-2.0 mm steel hook",
   "Tapestry needle, scissors"
  ]
 },
 "blue-floral-lace-crochet-sundress-mqchg47s": {
  "id": "014755b7-6169-4c6b-a627-33de8eb27978",
  "yarn": "#2-#3 sport/DK cotton, sapphire blue",
  "main_color": "Sapphire blue; green/white accents",
  "materials": [
   "#2-#3 sport/DK cotton, sapphire blue",
   "Green and white cotton scraps",
   "3.0-3.5 mm hook",
   "Tapestry needle, scissors",
   "Optional bodice lining"
  ]
 },
 "cat-amigurumi-airpods-case-cover-mq9vb460": {
  "id": "c5cdd2af-6609-4ff3-a413-0af7c76fb917",
  "yarn": "#1-#2 fingering cotton, gray and cream",
  "main_color": "Gray and cream; black/pink face",
  "materials": [
   "#1-#2 fingering yarn, gray and cream",
   "Black and pink yarn scraps",
   "2.0-3.0 mm hook",
   "Tapestry needle, stitch markers",
   "Small amount of stuffing",
   "Optional safety eyes",
   "Scissors"
  ]
 },
 "center-out-shell-stitch-square-baby-blanket-blue-ombre-mq5atg3u": {
  "id": "277729ec-99a2-4d55-a49a-f529f3c55cd4",
  "yarn": "#3-#4 soft baby yarn, blue ombre",
  "main_color": "White to blue ombre bands",
  "materials": [
   "#3-#4 soft baby yarn, acrylic/cotton",
   "White, light blue, medium blue",
   "4.0-4.5 mm hook (G/7)",
   "Tapestry needle, scissors"
  ]
 },
 "chunky-ribbed-throw-blanket-with-tassels-charcoal-mqsj71gv": {
  "id": "d2326f51-a5fc-444d-a9d9-98d2a0fac7c1",
  "yarn": "#5-#6 bulky yarn, charcoal grey",
  "main_color": "Charcoal grey, light grey tassels",
  "materials": [
   "#5-#6 bulky yarn, charcoal (5-8 skeins)",
   "Light grey yarn for tassels",
   "9-12 mm hook (M/N or larger)",
   "Tapestry needle, scissors",
   "Cardboard piece for tassels"
  ]
 },
 "cream-crochet-cross-car-charm-with-flowers-mqh2ph7h": {
  "id": "43c6f8b3-29a6-4473-b779-50872e97ddcb",
  "yarn": "#3-#4 DK/worsted yarn, cream/ecru",
  "main_color": "Cream; pink/peach flowers, green"
 },
 "crochet-amigurumi-cow-doll-in-milkmaid-dress-mqcjtlbm": {
  "id": "1f0ef437-acfb-4791-9efb-d7add9c2821f",
  "yarn": "DK cotton/acrylic, brown and white",
  "main_color": "Brown/white cow; light blue dress",
  "materials": [
   "DK cotton/acrylic yarn, six colors",
   "Safety eyes, polyester stuffing",
   "Embroidery thread (sunflower apron)",
   "2.5-3 mm hook",
   "Tapestry needle"
  ]
 },
 "crochet-bumblebee-keychain-amigurumi-bee-mqpmvbj1": {
  "id": "17363419-a070-49a4-bf64-1add545b9c25",
  "yarn": "4-ply sport cotton, yellow and black",
  "main_color": "Yellow and black stripes",
  "materials": [
   "4-ply cotton: yellow, black, white, pink",
   "6 mm black safety eyes (pair)",
   "Fiberfill stuffing",
   "Key ring or split ring",
   "2.5 mm hook",
   "Tapestry needle, stitch marker, scissors"
  ]
 },
 "crochet-christmas-angel-ornament-mqfiy02e": {
  "id": "b63f389c-447d-4a8a-b673-d870bfc1f30b",
  "yarn": "#3-#4 DK/worsted, sage green and cream",
  "main_color": "Sage robe, cream wings, wood"
 },
 "crochet-dragon-earflap-hat-mq8bemaq": {
  "id": "89599e1c-8a8f-41bd-bb26-67d33a6e7b6c",
  "main_color": "Sage green; cream, amber accents",
  "materials": [
   "#4 worsted acrylic/wool, sage green",
   "Cream/oatmeal yarn (horns, teeth)",
   "Pale yellow yarn scraps",
   "4.5-5.5 mm hook",
   "18-20 mm amber safety eyes",
   "Black yarn or felt (nostrils)",
   "Fiberfill stuffing",
   "Yarn needle, stitch markers, scissors",
   "Optional assembly pins"
  ]
 },
 "crochet-mesh-water-bottle-holder-with-smiley-daisy-mq9u5icd": {
  "id": "b06f4692-e00f-4429-8f02-48ac0e70ef46",
  "yarn": "#3-#4 DK/worsted cotton, sage green",
  "main_color": "Sage green; white & yellow daisy",
  "materials": [
   "#3-#4 DK/worsted cotton, sage green",
   "White & golden-yellow cotton (daisy)",
   "Black yarn or floss for smiley face",
   "3.5-4.0 mm hook",
   "Tapestry needle, scissors"
  ]
 },
 "crochet-tulip-flower-with-stem-and-leaves-mql5ttno": {
  "id": "0f009bea-51a4-47f4-aa0b-1ed0ebd99461",
  "yarn": "#1 fingering yarn, pink and green",
  "main_color": "Pink petals; green stem and leaves",
  "materials": [
   "#1 fingering yarn, pink (petals & bud)",
   "#1 fingering yarn, green (stem & leaves)",
   "Fiberfill stuffing",
   "Floral/craft wire for posable stem",
   "Small hook sized to fingering yarn",
   "Stitch marker, tapestry needle, scissors"
  ]
 },
 "daisy-flower-crochet-coaster-mug-mat-mq8hta1r": {
  "id": "a2280d5d-f7cb-41ab-8c26-d6c01f949378",
  "yarn": "#5-#6 bulky cotton cord, yellow & white",
  "main_color": "Golden-yellow center, white petals",
  "materials": [
   "#5-#6 bulky cotton cord, yellow & white",
   "5.0-6.0 mm hook",
   "Tapestry needle, scissors"
  ]
 },
 "dusty-rose-rectangular-rug-with-scattered-hearts-mqi5yzpr": {
  "id": "bf2f7cf4-d8c1-48ab-9dd2-ac3a323ee6b9",
  "yarn": "#5-#6 bulky cotton cord, dusty rose",
  "main_color": "Dusty rose; light-pink hearts",
  "materials": [
   "#5-#6 bulky cord, dusty rose",
   "Light-pink cord/yarn for hearts",
   "6.0-9.0 mm hook",
   "Tapestry needle, stitch markers, scissors",
   "Optional non-slip backing"
  ]
 },
 "granny-half-square-crochet-bandana-headscarf-mqpmpiv3": {
  "id": "7c402ec0-33e0-49c2-9068-0223028b7f0f",
  "yarn": "4-ply fingering cotton, four shades",
  "main_color": "Lilac, tan, cream, nectarine orange",
  "materials": [
   "4-ply fingering cotton, 4 shades",
   "3 mm hook (US D/3)",
   "Tapestry needle, scissors"
  ]
 },
 "granny-square-crochet-tote-bag-mqhzwvfg": {
  "id": "b7b6bee5-3dd1-4e5d-b329-7d9d67f84e19",
  "yarn": "#4 worsted cotton/acrylic, five colors",
  "main_color": "Red, teal, navy squares; oatmeal trim",
  "materials": [
   "#4 worsted cotton/acrylic, 5 colors",
   "4-5 mm hook",
   "Tapestry needle, scissors",
   "Optional fabric lining"
  ]
 },
 "green-mesh-crochet-placemats-with-daisy-border-mqflji3w": {
  "id": "d4c563d3-5d7b-4f8c-b58e-162722f9f10c",
  "yarn": "#3-#4 cotton, sage green",
  "main_color": "Sage green; white & yellow daisies"
 },
 "half-moon-rainbow-crochet-rug-boho-earth-tones-mqjl184i": {
  "id": "cb099d1f-9101-47a3-b100-2db8c12b54d2",
  "main_color": "Boho rainbow: cream, pink, blue, rust",
  "materials": [
   "#5-#6 bulky cotton/macrame cord",
   "Cream, pink, blue, gold, orange, rust",
   "6.0-9.0 mm hook",
   "Tapestry needle, scissors",
   "Cardboard for cutting fringe",
   "Optional non-slip backing"
  ]
 },
 "holy-trinity-in-crochet-mqf64x38": {
  "id": "5a71899e-5024-44dc-a4a1-e902872bdf08",
  "main_color": "Cream, browns, gray, gold accents",
  "materials": [
   "Yarn: cream, browns, beige, gray, gold",
   "White yarn (dove, book pages)",
   "Crochet hook sized to yarn",
   "Fiberfill stuffing for 3D parts",
   "Tapestry needle, scissors"
  ]
 },
 "hooded-baby-cocoon-sleep-sack-cable-bobble-basketweave-bear-set-mq5giq1i": {
  "id": "64e57c01-5836-4e89-9548-f368599777be",
  "yarn": "#5-#6 bulky baby yarn, mint or cream",
  "main_color": "Mint green or speckled cream",
  "materials": [
   "#5-#6 bulky soft baby yarn",
   "Mint or cream speckle; black for face",
   "5.5-8.0 mm hook (I-L)",
   "2 wooden buttons (collar tab)",
   "Tapestry needle, stitch markers, scissors",
   "Optional light stuffing for bear ears"
  ]
 },
 "lace-crochet-cross-bookmark-ornament-with-tassel-mqjyxrgt": {
  "id": "0c3148dd-15ea-44e9-a6d2-7d3989254c06",
  "yarn": "Size 10-20 cotton thread, lilac",
  "main_color": "Lilac/purple with pearl accents",
  "materials": [
   "Size 10/20 cotton thread, lilac",
   "1.5-2.0 mm steel hook",
   "Lilac satin ribbon for bow",
   "Pearl bead + gold seed beads",
   "Lilac thread or cord for tassel",
   "Tapestry needle, scissors",
   "Spray starch or fabric stiffener"
  ]
 },
 "lily-of-the-valley-crochet-coaster-mqlbt9lr": {
  "id": "0530eebf-0853-40ba-acd6-3940d1ea2e25",
  "yarn": "#2 sport cotton: blue, white, green",
  "main_color": "Blue base; white flowers, green leaves",
  "materials": [
   "#2 sport cotton: blue, white, green",
   "2.5 mm hook",
   "Tapestry needle, scissors"
  ]
 },
 "little-crochet-hearts-flat-applique-hearts-mqi4g6tg": {
  "id": "055b9611-a2ed-44ec-b780-b518a0c49709",
  "yarn": "#4 aran cotton scraps, assorted colors",
  "main_color": "Assorted brights & pastels",
  "materials": [
   "#4 aran cotton scraps, assorted colors",
   "3.5 mm hook",
   "Tapestry needle, scissors"
  ]
 },
 "manta-listrada-arco-iris-pastel": {
  "id": "46791777-de5a-46e6-9ddf-a9961df03147",
  "yarn": "#4 worsted acrylic, pastel rainbow",
  "main_color": "Pastel rainbow stripes on ivory",
  "materials": [
   "#4 worsted soft acrylic yarn",
   "Ivory plus 5-6 pastel shades",
   "5.0-5.5 mm hook (H/I)",
   "Tapestry needle, scissors"
  ]
 },
 "monarch-butterfly-crocodile-stitch-triangle-shawl-mq5btpcx": {
  "id": "9e35120b-18e1-4a7c-a0b3-6b96cdcf5e2d",
  "yarn": "#3-#4 yarn: orange, black, white",
  "main_color": "Monarch orange, black, white",
  "materials": [
   "#3-#4 yarn: orange, black, white/cream",
   "3.5-4.5 mm hook (E-G)",
   "Pearl beads for fringe",
   "Tapestry needle, scissors",
   "Stuffing/wire for butterfly; brooch pin"
  ]
 },
 "oval-granny-stripe-rug-plum-sage-cream-mq5ax6tc": {
  "id": "24897d95-f684-4aee-ad8f-edb946e0f084",
  "yarn": "#5-#6 bulky cotton cord, plum/sage/cream",
  "main_color": "Plum, sage & cream bands",
  "materials": [
   "#5-#6 bulky cotton or T-shirt cord",
   "3 colors: plum, sage green, cream/ecru",
   "5.5-7.0 mm hook (I-K)",
   "Tapestry needle, stitch markers, scissors"
  ]
 },
 "perfect-illusion-round-placemat-mqr21luz": {
  "id": "2e1d8530-0af6-4e78-a48f-64f0498dfa44",
  "yarn": "Natural raffia yarn, straw/beige",
  "main_color": "Natural raffia / straw beige",
  "materials": [
   "Raffia yarn, natural (~half roll each)",
   "4.5 mm crochet hook",
   "Yarn scrap as round marker",
   "Tapestry needle, scissors"
  ]
 },
 "pink-crochet-book-cover-with-flower-appliques-mq9ue965": {
  "id": "6a89ba51-56ef-47af-84b8-e2c1fd74312d",
  "yarn": "#4 worsted cotton/acrylic, pink",
  "main_color": "Pink with lilac flowers",
  "materials": [
   "#4 worsted cotton/acrylic yarn, pink",
   "Small amount of lilac yarn (flowers)",
   "4.0-4.5 mm hook",
   "Flower-shaped or small purple button",
   "Tapestry needle, scissors"
  ]
 },
 "pink-filet-crochet-throw-blanket-with-tassels-mqfjjicm": {
  "id": "0ff16829-189d-4194-8f38-36e5e5664951",
  "yarn": "#3-#4 cotton/acrylic yarn, soft pink",
  "main_color": "Solid soft pink"
 },
 "round-pink-crochet-rug-with-daisy-flower-border-mq9vz3q6": {
  "id": "e35e47a2-2e4f-451c-b52b-2d5bc31cf30d",
  "yarn": "#5-#6 bulky cotton cord, soft pink",
  "main_color": "Soft pink, white daisy border",
  "materials": [
   "#5-#6 bulky cotton cord, soft pink",
   "White and pink yarn (flower border)",
   "6.0-8.0 mm hook",
   "Tapestry needle, stitch markers, scissors",
   "Optional non-slip backing"
  ]
 },
 "shila-the-plush-unicorn-crochet-amigurumi-mqgz4iod": {
  "id": "8939b8df-1098-4d75-b768-12f87f0ee5c7",
  "yarn": "#6 chenille yarn: gray, purple, blue",
  "main_color": "Gray with purple, blue & pastels",
  "materials": [
   "#6 chenille yarn: gray, purple, blue",
   "#4 worsted pastels (mane and tail)",
   "21 mm safety eyes (pair)",
   "Fiberfill stuffing",
   "3.75 mm and 3.25 mm hooks",
   "Stitch marker, needle, pins, scissors",
   "Optional lashes and pink blush"
  ]
 },
 "snowman-character-ribbed-baby-beanie-mq79qqp1": {
  "id": "27569c30-8524-4dcc-b38b-22baa1ed34bc",
  "yarn": "#4 worsted acrylic, white",
  "main_color": "White with orange carrot nose",
  "materials": [
   "#4 worsted acrylic yarn, white (main)",
   "Scraps: black, gray, tan, orange, brown",
   "5.0-5.5 mm hook",
   "Small amount of fiberfill (nose)",
   "Tapestry needle, stitch markers, scissors"
  ]
 },
 "soft-pink-chenille-scarf-with-amigurumi-elephants-mqbb1e69": {
  "id": "31c73dc6-f0a0-483a-be7f-46293efa3bd4",
  "yarn": "#5-#6 chenille blanket yarn, soft pink",
  "main_color": "Soft pink, cream elephants",
  "materials": [
   "#5-#6 chenille yarn, soft pink (scarf)",
   "Cream and pink chenille (elephants)",
   "6.0-8.0 mm hook; 3.5-4.0 mm for elephants",
   "Fiberfill stuffing",
   "Black yarn or thread (eyes)",
   "Tapestry needle, scissors"
  ]
 },
 "strawberry-crochet-coaster-set-mqfjyadk": {
  "id": "fa5d3dfa-b97f-41c5-9b37-79b449b09272",
  "yarn": "#3-#4 cotton: red, white, green",
  "main_color": "Red, white seeds, green cap"
 },
 "sugar-skull-dia-de-los-muertos-crochet-rug-mq8hkhzu": {
  "id": "7d10ef45-6661-4919-b0da-22a73caea3d6",
  "yarn": "#5-#6 bulky cotton cord, cream",
  "main_color": "Cream with black & bright accents",
  "materials": [
   "#5-#6 bulky cotton cord, cream (body)",
   "Accents: black, magenta, gold, purple, green",
   "5.5-8.0 mm hook",
   "Tapestry needle, stitch markers, scissors",
   "Optional non-slip backing"
  ]
 },
 "teal-floral-granny-square-flower-center-motif-mqfnrf7s": {
  "id": "73abe495-5de2-4806-8a4a-25d68052de3c",
  "yarn": "#4 worsted yarn, teal (single color)",
  "main_color": "Solid teal",
  "materials": [
   "#4 worsted yarn, teal/petrol blue",
   "4.0-5.0 mm hook",
   "Tapestry needle, scissors"
  ]
 },
 "tiny-round-kitty-amigurumi-ball-shaped-cat-with-bow-mqr2cvb9": {
  "id": "d06caf2b-db2b-4dec-b36b-be5596fb979e",
  "yarn": "DK acrylic, white & red",
  "main_color": "White with red feet & bow",
  "materials": [
   "DK acrylic: white (10 g), red (8 g)",
   "Embroidery thread: black, blue, white, yellow",
   "Fiberfill stuffing",
   "3 mm hook (D/3)",
   "Stitch marker, tapestry needle, scissors"
  ]
 },
 "tiny-round-kitty-amigurumi-ball-shaped-cat-with-bow-mqsiyzt6": {
  "id": "33c48c29-41fe-4cef-af54-626a9f63fbf5",
  "yarn": "DK acrylic, white & red",
  "main_color": "White with red feet & bow",
  "materials": [
   "DK acrylic: white (10 g), red (8 g)",
   "Embroidery thread: black, blue, white, yellow",
   "Fiberfill stuffing",
   "3 mm hook (D/3)",
   "Stitch marker, tapestry needle, scissors"
  ]
 },
 "vintage-off-shoulder-irish-lace-crochet-maxi-dress-cream-teal-mq8hcnw3": {
  "id": "5f77a25d-419d-4051-b6d1-45a9ba52e007",
  "yarn": "Lace-weight cotton thread, cream & teal",
  "main_color": "Cream/ivory with teal borders",
  "materials": [
   "#0-#2 lace/fingering cotton, cream + teal",
   "Fine steel hook 1.75-3.0 mm",
   "Tapestry needle",
   "Pins and blocking board",
   "Scissors",
   "Optional bodice/skirt lining"
  ]
 },
 "watermelon-slice-amigurumi-keychain-mql9jixp": {
  "id": "ff4c7f7a-b856-4c7c-8ebb-13ddc15f5773",
  "yarn": "#3-#4 cotton/acrylic: red, white, green",
  "main_color": "Red, white & green watermelon",
  "materials": [
   "#3-#4 cotton/acrylic: red, white, green",
   "Black yarn or thread (face)",
   "3.0-3.5 mm hook",
   "Small amount of fiberfill",
   "Metal keyring with chain",
   "Tapestry needle, scissors"
  ]
 }
};

  const token = localStorage.getItem("sm_admin_jwt");
  if (!token) { console.error("Sem token — faça login no painel primeiro."); return; }
  const hdr = { Authorization: "Bearer " + token, "Content-Type": "application/json" };

  let ok = 0; const fail = [];
  for (const [slug, e] of Object.entries(SUMMARIES)) {
    try {
      const r = await fetch("/v1/admin/lessons/" + e.id, { headers: hdr });
      if (!r.ok) throw new Error("GET " + r.status);
      const { lesson } = await r.json();
      const meta = { ...(lesson.meta || {}) };
      if (e.yarn) meta.yarn = e.yarn;
      if (e.main_color) meta.main_color = e.main_color;
      if (e.materials) meta.materials = e.materials;
      const p = await fetch("/v1/admin/lessons/" + e.id, {
        method: "PATCH", headers: hdr, body: JSON.stringify({ meta }),
      });
      if (!p.ok) throw new Error("PATCH " + p.status);
      ok++; console.log("✓", slug);
    } catch (err) {
      fail.push(slug + ": " + err.message);
      console.warn("✗", slug, err.message);
    }
  }
  console.log(`Concluído: ${ok} aulas atualizadas, ${fail.length} falhas`, fail);
})();
