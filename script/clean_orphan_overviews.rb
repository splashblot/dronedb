DRY_MODE = ARGV[0] == 'delete' ? false : true

def remove_overviews(raster,user,schema)
  i = 0
  while i < 65
    exp = 2**i
    puts "the table #{scheme}.o_#{exp}_#{raster} from #{user}"
    if !DRY_MODE
      User.where(username: "#{user}").first().in_database["DROP TABLE IF EXISTS #{schema}.o_#{exp}_#{raster} CASCADE"].first()
    end
    i += 1
  end
end

def check_orphans(user,schema)
  orphans = User.where(username: "#{user}").first().in_database["SELECT table_name FROM information_schema.tables WHERE  table_name LIKE 'o\_1\_%\_raster%' and table_name NOT LIKE 'o\_16\_%\_raster%' AND table_schema = '#{schema}'"].all()
  orphans.each do |ov|
    #search for canonical table still in use
    ov[:table_name].slice! "o_1_"
    begin
      exist = User.where(username: "#{user}").first().in_database["SELECT count(*) FROM information_schema.tables where table_schema = '#{schema}' AND table_name = '#{ov[:table_name]}'"].first()
      if exist[:count] == 0
        remove_overviews(ov[:table_name],user,schema)
      end
    rescue
      puts "iteration failed over: " + schema + "." + table + " from " +user
    end
  end
end

User.all do |u|
  puts "########################## RASTER OVERVIEW USER"
  puts "Checking orphan overviews for: " +u.username.to_s
  check_orphans(u.username,u.database_schema)
end
