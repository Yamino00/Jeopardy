CREATE OR REPLACE FUNCTION normalizza(t TEXT) RETURNS TEXT AS $$
    SELECT regexp_replace(
             regexp_replace(
               regexp_replace(lower(unaccent(trim(t))),
                              '^(il|lo|la|i|gli|le|un|uno|una|l'')\s*', ''),
               '\s*\(.*\)\s*', ' ', 'g'),
             '[^a-z0-9 ]', '', 'g');
$$ LANGUAGE sql STABLE;
