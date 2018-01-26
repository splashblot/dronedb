require 'byebug'

def remove_overviews(raster,user,schema)
  i = 0
  while i < 32
    exp = 2**i
    puts "the table o_#{exp}_#{raster} from dev"
    # User.where(username: "#{user}").first().in_database["DROP TABLE IF EXISTS #{schema}.o_#{exp}_#{raster} CASCADE"].first()
    i += 1
  end
end

def check_orphans(user,schema)
  orphans = User.where(username: "#{user}").first().in_database["SELECT table_name FROM information_schema.tables WHERE  table_name LIKE 'o\_1\_%\_raster%' and table_name NOT LIKE 'o\_16\_%\_raster%'"].all()
  orphans.each do |ov|
    #search for canonical table still in use
    ov[:table_name].slice! "o_1_"
    begin
      User.where(username: "#{user}").first().in_database["SELECT cartodb_id FROM #{schema}.#{ov[:table_name]} LIMIT 1"].first()
    rescue
      remove_overviews(ov[:table_name],user,schema)
    end
  end
end

User.all do |u|
  puts "########################## RASTER OVERVIEW USER"
  puts "Checking orphan overviews for: " +u.username.to_s
  check_orphans(u.username,u.database_schema)
end
