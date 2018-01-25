# encoding: utf-8
require 'net/http'
require 'open-uri'
require_relative './column'
require_relative './job'
require_relative './query_batcher'
require_relative './content_guesser'

require_relative '../../../../lib/cartodb/stats/importer'
require_relative '../../../dataservices-metrics/lib/geocoder_usage_metrics'

module CartoDB
  module Importer2
    class HTTPMaxTrials < StandardError  
    end
    class HTTPUnexpectedError < StandardError  
    end 

    class Georeferencer
      DEFAULT_BATCH_SIZE = 50000
      GEOMETRY_POSSIBLE_NAMES   = %w{ geometry the_geom wkb_geometry geom geojson wkt }
      DEFAULT_SCHEMA            = 'cdb_importer'
      THE_GEOM_WEBMERCATOR      = 'the_geom_webmercator'
      DIRECT_STATEMENT_TIMEOUT  = 1.hour * 1000
      MAX_RETRY = 4
      SLEEP_TIME = 0.5

      def initialize(db, table_name, options, schema=DEFAULT_SCHEMA, job=nil, geometry_columns=nil, logger=nil)
        @db         = db
        @job        = job || Job.new({  logger: logger } )
        @table_name = table_name
        @schema     = schema
        @geometry_columns = geometry_columns || GEOMETRY_POSSIBLE_NAMES
        @from_geojson_with_transform = false
        @options = options
        @tracker = @options[:tracker] || lambda { |state| state }
        @content_guesser = CartoDB::Importer2::ContentGuesser.new(@db, @table_name, @schema, @options, @job)
        @importer_stats = CartoDB::Stats::Importer.instance
      end

      def set_importer_stats(importer_stats)
        @importer_stats = importer_stats
      end

      def mark_as_from_geojson_with_transform
        @from_geojson_with_transform = true
      end

      def run
        disable_autovacuum

        drop_the_geom_webmercator

        the_geom_column_name = create_the_geom_from_geometry_column  ||
          create_the_geom_from_referencia_catastral ||
          create_the_geom_from_ip_guessing      ||
          create_the_geom_from_namedplaces_guessing ||
          create_the_geom_from_country_guessing ||
          create_the_geom_in(table_name)

        enable_autovacuum

        raise GeometryCollectionNotSupportedError if get_geometry_type(the_geom_column_name || 'the_geom') == 'GEOMETRYCOLLECTION'
        self
      end

      def disable_autovacuum
        job.log "Disabling autovacuum for #{qualified_table_name}"
        db.run(%Q{
         ALTER TABLE #{qualified_table_name} SET (autovacuum_enabled = FALSE, toast.autovacuum_enabled = FALSE);
        })
      end

      def enable_autovacuum
        job.log "Enabling autovacuum for #{qualified_table_name}"
        db.run(%Q{
         ALTER TABLE #{qualified_table_name} SET (autovacuum_enabled = TRUE, toast.autovacuum_enabled = TRUE);
        })
      end

      def http_request(uri, trial=0, max_trials=MAX_RETRY, sleep_time=SLEEP_TIME)
        sleep SLEEP_TIME if trial > 0
        response = Net::HTTP.get_response(uri)	
        if response.kind_of? Net::HTTPServerError
          if (trial + 1) >= MAX_RETRY
            raise HTTPMaxTrials, %Q{Max retrials #{trial+1} for uri '#{uri}' reached.}
          end
          return http_request(uri, trial + 1, max_trials, sleep_time)
        end
        if not response.kind_of? Net::HTTPSuccess
          raise HTTPUnexpectedError, %Q{Unexpected response for uri #{uri}. Response code #{response.code}}
        else         
          return response
        end
      end

      def construct_sigpac_polygon(rc)
	uri = URI.parse("http://ovc.catastro.meh.es/INSPIRE/wfsCP.aspx?service=wfs&version=2&request=getfeature&STOREDQUERIE_ID=GetParcel&refcat=" + rc.to_s + "&srsname=EPSG::25830")
        response = http_request(uri)
	xml = Nokogiri.XML(response.body)
        s = xml.xpath("//gml:posList").text
        cleanrefcatgeom = ''
        space = 0
        for pos in 0...s.length
          if (s[pos] == " ")
            space += 1
            if (space % 2 == 0)
              s[pos] = ","
             end
          end
          cleanrefcatgeom = cleanrefcatgeom + s[pos]
        end
        transformedgeom = db[%Q{ SELECT ST_AsText(ST_Transform(ST_GeomFromText(\'POLYGON((#{cleanrefcatgeom}))\',25830),4326)) As wgs_geom }].first
        transformedgeom[:wgs_geom]       
      end

      def create_the_geom_from_referencia_catastral
        look_for_columns = ['provincia', 'municipio', 'poligono', 'parcela']
        n_col = 0
        column_for = transliterated_columns(table_name)
        columns = {}
        look_for_columns.each do |search_column|
          n_col = n_col + 1 if column_for.keys.include? search_column
        end
        column_for_rc = column_for["referencia_catastral"] || column_for["referencia catastral"]
        has_provincia_municipio = n_col == 4
        has_rc = column_for_rc || false
        if has_provincia_municipio || has_rc
          create_the_geom_in table_name          
        else
          return false
        end
        if has_provincia_municipio
          catastral_data = db[%Q{ SELECT distinct "#{ column_for["provincia"] }" as provincia,"#{ column_for["municipio"] }" as municipio,"#{ column_for["poligono"] }" as poligono ,"#{ column_for["parcela"] }" as parcela from #{schema}.#{table_name}}]           
          catastral_data.each do |cd|
            begin
              next if cd[:provincia].blank? || cd[:municipio].blank? || cd[:poligono].blank? || cd[:parcela].blank?
              uri = URI.parse("http://ovc.catastro.meh.es/ovcservweb/OVCSWLocalizacionRC/OVCCallejero.asmx/Consulta_DNPPP?provincia=" +URI.escape(cd[:provincia].to_s)  + "&municipio=" + URI.escape(cd[:municipio].to_s) + "&poligono="+  URI.escape(cd[:poligono].to_s) +"&parcela="+  URI.escape(cd[:parcela].to_s) )
              response = http_request(uri)
              response = Nokogiri.XML(response.body)
              next if response.css("pc1").first.nil? # invalid address
              comp_ref_cat = response.css("pc1").first.content + response.css("pc2").first.content
              refcatgeom = construct_sigpac_polygon(comp_ref_cat)
              if refcatgeom
                db[%Q{ UPDATE #{schema}.#{table_name} set the_geom = ST_GeomFromText(\'#{refcatgeom}\',4326) WHERE "#{ column_for["provincia"] }" = \'#{cd[:provincia]}\' AND "#{ column_for["municipio"] }" = \'#{cd[:municipio]}\' AND "#{ column_for["poligono"] }" = \'#{cd[:poligono]}\' AND "#{ column_for["parcela"] }" = \'#{cd[:parcela]}\' }].first
              end
            rescue => ex
              message = "Fail iterating over referencia catastral with municipio on #{cd.inspect} with #{ex.message}"
              CartoDB::Logger.warning(exception: ex,
                                      message: message,
                                      user_id: @job.logger.user_id)
              job.log "WARNING: #{message}"
              next
            end
          end 
        end
        if has_rc
          uri = ""
          rcs = db[%Q{ SELECT distinct "#{column_for_rc}" as referencia_catastral from #{schema}.#{table_name}}]
          rcs.each do |eachrc| 
            begin
              rc = eachrc[:referencia_catastral].to_s
              next if rc.blank? # empty referencia_catastral
              rc = rc.strip

              refcatgeom = construct_sigpac_polygon(rc)
              if refcatgeom
                db[%Q{ UPDATE #{schema}.#{table_name} set the_geom = ST_GeomFromText(\'#{refcatgeom}\',4326) WHERE "#{column_for_rc}" = \'#{rc}\' }].first
              end
            rescue => ex
              message = "Fail iterating over referencia catastral with rc on #{eachrc.inspect} with #{ex.message}"
              CartoDB::Logger.warning(exception: ex,
                                      message: message,
                                      user_id: @job.logger.user_id)
              job.log "WARNING: #{message}"
              next
            end
          end           
        end
        'the_geom'
      rescue => ex
        message = "Importing Referencia Catastral failed: #{ex.message}"
        CartoDB::Logger.warning(exception: ex,
                                message: message,
                                user_id: @job.logger.user_id)
        job.log "WARNING: #{message}"
        false
      end

      def normalize_column(column)
        ActiveSupport::Inflector.transliterate(column).downcase.strip
      end

      def transliterated_columns(tablename)
        Hash[columns_in(tablename).collect{|column| [normalize_column(column.to_s), column]}]
      end

      def create_the_geom_from_geometry_column
        geometry_column_name = geometry_column_in
        return false unless geometry_column_name
        job.log "Creating the_geom from #{geometry_column_name} column"
        column = Column.new(db, table_name, geometry_column_name, user, schema, job)
        column.mark_as_from_geojson_with_transform if @from_geojson_with_transform
        column.empty_lines_to_nulls
        column.geometrify

        column_name = geometry_column_name
        if column_exists_in?(table_name, 'the_geom')
          geometry_type = get_geometry_type('the_geom') rescue nil
          if geometry_type.nil? || geometry_type == 'GEOMETRYCOLLECTION'
            invalid_the_geom = get_column('the_geom')
            if !column_exists_in?(table_name, 'invalid_the_geom')
              invalid_the_geom.rename_to('invalid_the_geom')
            end
          end
        end

        unless column_exists_in?(table_name, 'the_geom')
          column_name = 'the_geom'
          column.rename_to(column_name)
        end

        handle_multipoint(qualified_table_name) if multipoint?
        column_name
      rescue => exception
        job.log "Error creating the_geom: #{exception}. Trace: #{exception.backtrace}"
        if /statement timeout/.match(exception.message).nil?
          if column.empty?
            job.log "Dropping empty #{geometry_column_name}"
            column.drop
          else
            # probably this one needs to be kept doing... but how if times out?
            job.log "Renaming #{geometry_column_name} to invalid_the_geom"
            column.rename_to(:invalid_the_geom)
          end
        end
        false
      end

      def create_the_geom_from_country_guessing
        return false if not @content_guesser.enabled?
        return false if @content_guesser.sample.count == 0
        job.log 'Trying country guessing...'
        begin
          country_column_name = nil
          @importer_stats.timing('guessing') do
            @tracker.call('guessing')
            country_column_name = @content_guesser.country_column
            @tracker.call('importing')
          end
          if country_column_name
            job.log "Found country column: #{country_column_name}"
            create_the_geom_in table_name
            return geocode_countries country_column_name
          end
        rescue Exception => ex
          message = "create_the_geom_from_country_guessing failed: #{ex.message}"
          CartoDB::Logger.warning(exception: ex,
                                  message: message,
                                  user_id: @job.logger.user_id)
          job.log "WARNING: #{message}"
        end
        return false
      end

      def create_the_geom_from_namedplaces_guessing
        return false if not @content_guesser.enabled?
        return false if @content_guesser.sample.count == 0
        job.log 'Trying namedplaces guessing...'
        begin
          @importer_stats.timing('guessing') do
            @tracker.call('guessing')
            @content_guesser.namedplaces.run!
            @tracker.call('importing')
          end
          if @content_guesser.namedplaces.found?
            job.log "Found namedplace column: #{@content_guesser.namedplaces.column}"
            create_the_geom_in table_name
            return geocode_namedplaces
          end
        rescue Exception => ex
          message = "create_the_geom_from_namedplaces_guessing failed: #{ex.message}"
          CartoDB::Logger.warning(exception: ex,
                                  message: message,
                                  user_id: @job.logger.user_id)
          job.log "WARNING: #{message}"
        end
        return false
      end

      def create_the_geom_from_ip_guessing
        return false if not @content_guesser.enabled?
        return false if @content_guesser.sample.count == 0
        job.log 'Trying ip guessing...'
        begin
          ip_column_name = nil
          @importer_stats.timing('guessing') do
            @tracker.call('guessing')
            ip_column_name = @content_guesser.ip_column
            @tracker.call('importing')
          end
          if ip_column_name
            job.log "Found ip column: #{ip_column_name}"
            return geocode_ips ip_column_name
          end
        rescue Exception => ex
          message = "create_the_geom_from_ip_guessing failed: #{ex.message}"
          CartoDB::Logger.warning(exception: ex,
                                  message: message,
                                  user_id: @job.logger.user_id)
          job.log "WARNING: #{message}"
          return false
        end
      end

      def geocode_countries country_column_name
        job.log "Geocoding countries..."
        geocode(country_column_name, 'polygon', 'admin0')
      end

      def geocode_namedplaces
        job.log "Geocoding namedplaces..."
        geocode(@content_guesser.namedplaces.column[:column_name],
                'point',
                'namedplace',
                @content_guesser.namedplaces.country_column_name,
                @content_guesser.namedplaces.country)
      end

      def geocode_ips ip_column_name
        job.log "Geocoding ips..."
        geocode(ip_column_name, 'point', 'ipaddress')
      end

      def geocode(formatter, geometry_type, kind, country_column_name=nil, country=nil)
        geocoder = nil
        @importer_stats.timing("geocoding.#{kind}") do
          @tracker.call('geocoding')
          create_the_geom_in(table_name)
          orgname = user.organization.nil? ? nil : user.organization.name
          usage_metrics = CartoDB::GeocoderUsageMetrics.new(user.username, orgname)
          config = @options[:geocoder].merge(
            table_schema: schema,
            table_name: table_name,
            qualified_table_name: qualified_table_name,
            connection: db,
            formatter: formatter,
            geometry_type: geometry_type,
            kind: kind,
            max_rows: nil,
            country_column: country_column_name,
            countries: country.present? ? "'#{country}'" : nil,
            usage_metrics: usage_metrics
          )
          geocoding = Geocoding.new config.slice(:kind, :geometry_type, :formatter, :table_name, :country_column, :country_code)
          geocoding.user = user
          geocoding.data_import_id = data_import.id unless data_import.nil?
          geocoding.raise_on_save_failure = true
          geocoder = CartoDB::InternalGeocoder::Geocoder.new(config.merge!(geocoding_model: geocoding))
          geocoder.set_log(geocoding.log)
          geocoding.force_geocoder(geocoder)
          begin
            geocoding.run_geocoding!(row_count)
            raise "Geocoding failed" if geocoding.state == 'failed'
          rescue => e
            config_info = config.select {|key, value| [:table_schema, :table_name, :qualified_table_name, :formatter, :geometry_type, :kind, :max_rows, :country_column, ].include?(key) }
            CartoDB::Logger.error(exception: e,
                                  message: 'Georeferencer could not register geocoding, fallback to geocoder.run',
                                  user_id: user_id,
                                  config: config_info)
            geocoder.run
          end

          job.log "Geocoding finished"
        end
        geocoder.state == 'completed'
        'the_geom'
      end

      def row_count
        @row_count ||= db[%Q{select count(1) from #{qualified_table_name}}].first[:count]
      end

      def data_import
        @data_import ||= DataImport.where(logger: @job.logger.id).first
      end

      def user
        @user ||= ::User.where(id: user_id).first
      end

      def user_id
        @job.logger.user_id
      end

      def create_the_geom_in(table_name)
        job.log 'Creating the_geom column'
        return false if column_exists_in?(table_name, 'the_geom')

        db.run(%Q{
          SELECT public.AddGeometryColumn(
            '#{schema}','#{table_name}','the_geom',4326,'geometry',2
          );
        })
        'the_geom'
      end

      def column_exists_in?(table_name, column_name)
        columns_in(table_name).include?(column_name.to_sym)
      end

      def columns_in(table_name)
        db.schema(table_name, reload: true, schema: schema).map(&:first)
      end

      def geometry_column_in
        names = geometry_columns.map { |name| "'#{name}'" }.join(',')
        find_column_in(table_name, names)
      end

      def drop_the_geom_webmercator
        return self unless column_exists_in?(table_name, THE_GEOM_WEBMERCATOR)

        job.log 'Dropping the_geom_webmercator column'
        column = Column.new(db, table_name, THE_GEOM_WEBMERCATOR, user, schema, job)
        column.drop
      end

      def get_column(column = :the_geom)
        Column.new(db, table_name, column, user, schema, job)
      end

      def get_geometry_type(column = :the_geom)
        get_column(column).geometry_type
      end

      def find_column_in(table_name, possible_names)
        sample = db[%Q{
          SELECT  column_name
          FROM    information_schema.columns
          WHERE   table_name = '#{table_name}'
          AND     table_schema = '#{schema}'
          AND     lower(column_name) in (#{possible_names})
          LIMIT   1
        }].first

        !!sample && sample.fetch(:column_name, false)
      end

      def handle_multipoint(qualified_table_name)
        # TODO: capture_exceptions=true
        job.log 'Converting detected multipoint to point'

        user.db_service.in_database_direct_connection(statement_timeout: DIRECT_STATEMENT_TIMEOUT) do |user_direct_conn|
            user_direct_conn.run(%Q{
                                    UPDATE #{qualified_table_name}
                                    SET the_geom = ST_GeometryN(the_geom, 1)
                                    })
        end
      end

      def multipoint?
        is_multipoint = db[%Q{
          SELECT public.GeometryType(the_geom)
          FROM #{qualified_table_name}
          AS geometrytype
        }].first.fetch(:geometrytype) == 'MULTIPOINT'

        job.log 'found MULTIPOINT geometry' if is_multipoint

        is_multipoint
      rescue
        false
      end

      private

      attr_reader :db, :table_name, :schema, :job, :geometry_columns

      def qualified_table_name
        %Q("#{schema}"."#{table_name}")
      end
    end
  end
end
