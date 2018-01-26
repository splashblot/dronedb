require 'byebug'

def remove_overviews raster
  i = 0
  while i < 32
    exp = 2**i
    User.where(username: "dev").first().in_database["DROP TABLE IF EXISTS o_#{exp}_#{raster} CASCADE"].first()
    i += 1
  end
end

orphans = User.where(username: "dev").first().in_database["SELECT table_name FROM information_schema.tables WHERE  table_name LIKE 'o\_1\_%\_raster%' and table_name NOT LIKE 'o\_16\_%\_raster%'"].all()
orphans.each do |ov|
  #search for canonical table still in use
  ov[:table_name].slice! "o_1_"
  begin
    User.where(username: "dev").first().in_database["SELECT cartodb_id FROM public.#{ov[:table_name]} LIMIT 1"].first()
  rescue
    remove_overviews ov[:table_name]
  end
end
