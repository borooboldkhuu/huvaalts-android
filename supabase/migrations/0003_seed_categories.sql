-- Seed data for the fixed top-level categories shown on Home (spec section 11).
insert into public.categories (id, name_mn, name_en, icon, sort_order) values
  ('camera', 'Камер', 'Camera', 'camera_alt', 1),
  ('drone', 'Дрон', 'Drone', 'flight', 2),
  ('gaming', 'Gaming', 'Gaming', 'sports_esports', 3),
  ('tools', 'Tools', 'Tools', 'handyman', 4),
  ('audio', 'Audio', 'Audio', 'speaker', 5),
  ('event', 'Event', 'Event', 'celebration', 6),
  ('vehicle', 'Vehicle', 'Vehicle', 'directions_car', 7),
  ('space', 'Space', 'Space', 'meeting_room', 8),
  ('other', 'Бусад', 'Other', 'category', 9)
on conflict (id) do nothing;
