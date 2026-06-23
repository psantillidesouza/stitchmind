-- Biblioteca de receitas (patterns) servida pelo backend (antes era asset local)

CREATE TABLE IF NOT EXISTS patterns (
  id               text PRIMARY KEY,
  name             text NOT NULL,
  author           text NOT NULL DEFAULT 'StitchMind',
  technique        text NOT NULL CHECK (technique IN ('crochet','knit')),
  difficulty       text NOT NULL CHECK (difficulty IN ('beginner','intermediate','advanced')),
  yarn_requirement text NOT NULL DEFAULT '',
  estimated_hours  integer NOT NULL DEFAULT 0,
  suggested_needle text,
  description      text NOT NULL DEFAULT '',
  sections         jsonb NOT NULL DEFAULT '[]',
  status           text NOT NULL DEFAULT 'published' CHECK (status IN ('draft','published')),
  order_index      integer NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_patterns_status ON patterns(status, order_index);

-- Seed: as 3 receitas que antes eram do asset local (assets/data/patterns.json)
INSERT INTO patterns (id, name, author, technique, difficulty, yarn_requirement, estimated_hours, suggested_needle, description, sections, order_index) VALUES
(
  'pt-001', 'Classic Granny Square Blanket', 'StitchMind', 'crochet', 'beginner',
  '800g in assorted colors (cotton or medium acrylic)', 22, '4.5 mm',
  'Classic blanket made of 12×12 cm granny squares. Mix colors freely — the more variety, the more charm.',
  $j$[{"title":"Granny Square (× 30)","subtitle":"Repeat 30 times, alternating 3-color combinations.","rows":[{"row":1,"instruction":"Magic ring. Ch 3 (counts as 1st dc), 2 dc, ch 3, *3 dc, ch 3* × 3. Join with sl st at the top of the starting ch 3.","stitch_count":12},{"row":2,"instruction":"Change color. In each ch-3 space: 3 dc, ch 3, 3 dc. Between corners: ch 1. Join.","stitch_count":24},{"row":3,"instruction":"Change color. Corners as in row 2. In the side spaces work 3 dc with ch 1 before and after. Join.","stitch_count":36},{"row":4,"instruction":"Continue with the 3rd color. Corners 3 dc/ch 3/3 dc. Sides: 3 dc, ch 1 between each group. Join and fasten off."}]},{"title":"Joining the squares","subtitle":"Lay them out in a 5×6 grid.","rows":[{"row":1,"instruction":"Join the squares in pairs with slip stitch through the outer loops, forming rows of 5."},{"row":2,"instruction":"Repeat, joining the rows horizontally."}]},{"title":"Final border","rows":[{"row":1,"instruction":"In a single color, edge the whole blanket with sc. At corners work 3 sc in the same stitch."},{"row":2,"instruction":"Shell row: *skip 2 stitches, 5 dc in the next, skip 2, sc*. Fasten off."}]}]$j$::jsonb,
  0
),
(
  'pt-002', 'Bunny Amigurumi', 'Maria Souza', 'crochet', 'beginner',
  '120g of fine cotton (main color + white for the tail)', 8, '2.5 mm',
  '18 cm bunny with long ears. Fiberfill stuffing. Use 6 mm safety eyes.',
  $j$[{"title":"Head","rows":[{"row":1,"instruction":"Magic ring with 6 sc.","stitch_count":6},{"row":2,"instruction":"Increase in each stitch.","stitch_count":12},{"row":3,"instruction":"*sc, increase*, repeat 6 times.","stitch_count":18},{"row":4,"instruction":"*2 sc, increase*, repeat 6 times.","stitch_count":24},{"row":5,"instruction":"*3 sc, increase*, repeat 6 times.","stitch_count":30},{"row":6,"instruction":"30 sc.","stitch_count":30},{"row":7,"instruction":"30 sc.","stitch_count":30},{"row":8,"instruction":"30 sc. Insert the eyes between rows 6 and 7.","stitch_count":30},{"row":9,"instruction":"*3 sc, decrease*, repeat 6 times.","stitch_count":24},{"row":10,"instruction":"*2 sc, decrease*, repeat 6 times. Start stuffing.","stitch_count":18},{"row":11,"instruction":"*sc, decrease*, repeat 6 times.","stitch_count":12},{"row":12,"instruction":"6 decreases. Close and fasten off.","stitch_count":6}]},{"title":"Ears (× 2)","rows":[{"row":1,"instruction":"Magic ring with 6 sc.","stitch_count":6},{"row":2,"instruction":"Increase in each stitch.","stitch_count":12},{"row":3,"instruction":"12 sc for 6 rows straight, no increases.","stitch_count":12},{"row":9,"instruction":"Flatten: close the ear with 6 sc, working through both edges together."}]},{"title":"Body","rows":[{"row":1,"instruction":"Magic ring with 6 sc. Work progressive increases up to 30 sc, following the same pattern as the head."},{"row":2,"instruction":"30 sc for 8 rows. Shape into a pear silhouette."},{"row":3,"instruction":"Decrease gradually down to 6 sc. Stuff firmly before closing."}]},{"title":"Legs (× 4)","rows":[{"row":1,"instruction":"Magic ring with 6 sc. Increase to 12 sc."},{"row":2,"instruction":"12 sc for 4 rows. Stuff and close with 6 decreases."}]},{"title":"Tail","rows":[{"row":1,"instruction":"In white: magic ring with 6 sc. Increase to 12 sc. 12 sc. Close with 6 decreases."}]},{"title":"Assembly","rows":[{"row":1,"instruction":"Sew the head to the body at the narrowest part."},{"row":2,"instruction":"Position the ears on top of the head."},{"row":3,"instruction":"Sew on the 4 legs and the tail. Embroider the nose in pink and whiskers in black."}]}]$j$::jsonb,
  1
),
(
  'pt-003', 'Winter Beret', 'Joana Lima', 'knit', 'intermediate',
  '150g of chunky wool (bulky weight)', 6, '5 mm circular + 6 mm',
  'Slouchy beret in stockinette with a 2×2 rib at the brim. One size, fits 54–58 cm well.',
  $j$[{"title":"Ribbed brim","subtitle":"5 mm circular needle.","rows":[{"row":1,"instruction":"Cast on 96 stitches. Join in the round, taking care not to twist."},{"row":2,"instruction":"*k2, p2*, repeat to the end of the round."},{"row":3,"instruction":"Keep the 2×2 rib for 12 rounds (about 5 cm)."}]},{"title":"Body of the beret","subtitle":"Switch to the 6 mm needle.","rows":[{"row":13,"instruction":"Increase evenly to 120 stitches. Continue in stockinette."},{"row":14,"instruction":"Knit in stockinette for 18 rounds (about 11 cm)."}]},{"title":"Crown","rows":[{"row":32,"instruction":"Divide into 12 sectors of 10 stitches. Mark with stitch markers."},{"row":33,"instruction":"Decrease round: *k8, k2tog*. (108 stitches)"},{"row":34,"instruction":"1 round in stockinette."},{"row":35,"instruction":"Decrease: *k7, k2tog*. (96 stitches)"},{"row":36,"instruction":"1 round in stockinette."},{"row":37,"instruction":"Continue alternating — decrease on every odd round until 12 stitches remain."},{"row":50,"instruction":"Cut the yarn, thread it through a tapestry needle and through all stitches. Pull tight to close the top."}]}]$j$::jsonb,
  2
)
ON CONFLICT (id) DO NOTHING;
