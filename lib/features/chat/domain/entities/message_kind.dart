/// Mirrors the `messages.kind` check constraint
/// (`supabase/migrations/0001_init_schema.sql`). Only `text` and `system`
/// are ever produced by this phase's UI — `image` needs Storage wiring
/// for chat attachments (deferred, see README "Known issues"),
/// `bookingReference`/`assetReference` are richer message types with no
/// composer UI yet. All five are still modeled here so a message of any
/// kind that shows up later (e.g. seeded server-side) renders as
/// *something* recognizable instead of crashing a `switch`.
enum MessageKind {
  text('text'),
  image('image'),
  system('system'),
  bookingReference('booking_reference'),
  assetReference('asset_reference');

  const MessageKind(this.id);

  final String id;

  static MessageKind fromId(String id) {
    return MessageKind.values.firstWhere((k) => k.id == id, orElse: () => MessageKind.text);
  }
}
