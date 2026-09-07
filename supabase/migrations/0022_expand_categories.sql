-- Expands the 9-category set from 0003_seed_categories.sql to the fuller
-- 16-category list the user asked for. `assets.category_id` is a foreign
-- key into `public.categories` (0001_init_schema.sql), so every id
-- `AssetCategory` (lib/core/constants/asset_categories.dart) can produce
-- must exist here first, or asset creation with a new category fails with
-- a foreign-key violation.
--
-- `space` ('Талбай') is not in the user's new list. It is deliberately
-- deactivated (`is_active = false`), not deleted: if any asset already
-- references it, `delete from categories where id = 'space'` would fail
-- outright on the `assets.category_id` foreign key (no ON DELETE clause
-- was ever set — see 0001's `create table public.assets`, so the default
-- is `NO ACTION`), and even a successful delete would silently orphan
-- that asset's category. `is_active = false` hides it from any future
-- UI that queries this table directly without touching existing rows —
-- today's client-side `AssetCategory` enum doesn't query this table at
-- all (see that file's doc comment), so this is a forward-looking
-- consistency fix, not something the app currently reads.
update public.categories set is_active = false where id = 'space';

insert into public.categories (id, name_mn, name_en, icon, sort_order) values
  ('electronics', 'Компьютер & Электрон бараа', 'Computers & Electronics', 'computer', 3),
  ('projector', 'Проектор & Дэлгэц', 'Projectors & Screens', 'slideshow', 6),
  ('travel', 'Аялал & Зуслангийн хэрэгсэл', 'Travel & Camping', 'hiking', 9),
  ('sports', 'Спорт & Дасгал', 'Sports & Fitness', 'fitness_center', 10),
  ('household', 'Гэр ахуйн хэрэгсэл', 'Household', 'chair', 12),
  ('office', 'Оффисын хэрэгсэл & Тоног төхөөрөмж', 'Office Supplies & Equipment', 'business_center', 13),
  ('kids', 'Хүүхдийн хэрэгсэл', 'Kids'' Gear', 'child_care', 14),
  ('fashion', 'Хувцас & Гоёл чимэглэл', 'Fashion & Accessories', 'checkroom', 15),
  ('construction', 'Барилга & Хүнд тоног төхөөрөмж', 'Construction & Heavy Equipment', 'construction', 16)
on conflict (id) do nothing;

-- Re-point sort_order and names for the ids that were already seeded by
-- 0003 but now carry the user's fuller label (e.g. 'camera' was just
-- 'Камер', now 'Камер & Зураг авалт') and a new position in the 16-item
-- order the user gave. `on conflict do nothing` above can't do this
-- (it only handles genuinely new rows), so these are explicit updates.
update public.categories set name_mn = 'Камер & Зураг авалт', name_en = 'Camera & Photography', sort_order = 1 where id = 'camera';
update public.categories set name_mn = 'Дрон', name_en = 'Drones', sort_order = 2 where id = 'drone';
update public.categories set name_mn = 'Тоглоомын төхөөрөмж', name_en = 'Gaming', sort_order = 4 where id = 'gaming';
update public.categories set name_mn = 'Дуу хөгжим & Аудио төхөөрөмж', name_en = 'Music & Audio', sort_order = 5 where id = 'audio';
update public.categories set name_mn = 'Арга хэмжээ & Үдэшлэг', name_en = 'Events & Parties', sort_order = 7 where id = 'event';
update public.categories set name_mn = 'Багаж хэрэгсэл & Засвар', name_en = 'Tools & Repair', sort_order = 8 where id = 'tools';
update public.categories set name_mn = 'Машин & Тээврийн хэрэгсэл', name_en = 'Cars & Vehicles', sort_order = 11 where id = 'vehicle';
update public.categories set sort_order = 17 where id = 'other';
