# encoding: utf-8
require 'open3'
require_relative './exceptions'

module CartoDB
  module Importer2
    class Raster2Pgsql
      SCHEMA                        = 'cdb_importer'
      PROJECTION                    = 3857
      BLOCKSIZE                     = '128x128'
      DOWNSAMPLED_FILENAME          = '%s_downsampled.tif'
      WEBMERCATOR_FILENAME          = '%s_webmercator.vrt'
      ALIGNED_WEBMERCATOR_FILENAME  = '%s_aligned_webmercator.vrt'
      ALIGNED_WEBMERCATOR_TIF_FILENAME  = '%s_aligned_webmercator.tif'
      RASTER2PSQL_FILENAME          = '%s.sql'
      RASTER2PSQL_ORIGINAL_FILENAME = '%s_original.sql'
      SQL_FILENAME                  = '%s%s.sql'
      OVERLAY_TABLENAME             = 'o_%s_%s'
      RASTER_COLUMN_NAME            = 'the_raster_webmercator'
      GDALWARP_COMMON_OPTIONS       = ['-wm', '200', '-multi'].freeze
      GDALTRANSLATE_COMMON_OPTIONS  = ['-co', 'COMPRESS=LZW', '-co', 'BIGTIFF=YES', '-co', 'TILED=YES'].freeze
      MAX_REDUCTED_SIZE             = 256
      DEFAULT_STATEMENT_TIMEOUT     = 10 * 60 * 1000 # ms

      def initialize(table_name, filepath, pg_options, db)
        self.filepath             = filepath
        self.basepath             = filepath.slice(0, filepath.rindex('/')+1)
        file_basename             = filepath.gsub(/\.tif$/, '') 
        self.webmercator_filepath = WEBMERCATOR_FILENAME % [file_basename]
        self.aligned_filepath     = ALIGNED_WEBMERCATOR_FILENAME % [file_basename]
        self.aligned_tif_filepath = ALIGNED_WEBMERCATOR_TIF_FILENAME % [file_basename]
        self.downsampled_filepath = DOWNSAMPLED_FILENAME % [file_basename]
        self.raster2psql_filepath = RASTER2PSQL_FILENAME % [file_basename]
        self.raster2psql_original_filepath = RASTER2PSQL_ORIGINAL_FILENAME % [file_basename]
        self.pg_options           = pg_options
        self.table_name           = table_name
        self.exit_code            = nil
        self.command_output       = ''
        self.additional_tables    = []
        self.db                   = db
        self.base_table_fqtn      = SCHEMA + '.' + table_name
        self.statement_timeout    = Cartodb.get_config(:importer, 'statement_timeout') || DEFAULT_STATEMENT_TIMEOUT
      end

      attr_reader   :exit_code, :command_output

      def run
        if need_downsample?
          downsample_raster
          reproject_raster(downsampled_filepath)
        else
          reproject_raster(filepath)
        end

        size = extract_raster_size
        pixel_size = extract_pixel_size

        overviews_list = calculate_raster_overviews(size)
        scale = calculate_raster_scale(pixel_size)

        align_raster(scale)
        convert_vrt_to_tif

        run_raster2pgsql(overviews_list)

        add_raster_base_overview_for_tiler
        import_original_raster
        self
      end

      # Execute DB code inside a transaction with an optional statement timeout.
      # This is the only way to have the SQL in the block executed with
      # the desired statement_timeout when the connection goes trhough
      # pgbouncer configured with pool mode as 'transaction'.      
      def transaction_with_timeout
        db.transaction do
          begin
            db.run("SET statement_timeout TO #{statement_timeout}") if statement_timeout
            yield db
            db.run('SET statement_timeout TO DEFAULT')
          end
        end
      end

      def need_downsample?
        # There is no less than Byte type in GDAL Byte/Int16/UInt16/UInt32/Int32/Float32/Float64/CInt16/CInt32/CFloat32/CFloat64
        bands_type = extract_bands_type
        bands_type.select{|band| band.downcase!='byte'}.size > 0
      end

      # Returns a list of additional support tables created, that should go to the user DB
      # but not get cartodbfied/shown on the dashboard
      def additional_support_tables
        additional_tables.map { |scale| OVERLAY_TABLENAME % [scale, table_name] }
      end

      private

      attr_writer   :exit_code, :command_output
      attr_accessor :filepath, :pg_options, :table_name, :webmercator_filepath, :aligned_filepath, :aligned_tif_filepath, \
                    :basepath, :additional_tables, :db, :base_table_fqtn, :downsampled_filepath, :raster2psql_filepath, \
                    :raster2psql_original_filepath, :statement_timeout

      def downsample_raster
        gdal_translate_command = [gdal_translate_path, '-scale', '-ot', 'Byte', GDALTRANSLATE_COMMON_OPTIONS, filepath, downsampled_filepath].flatten

        stdout, stderr, status  = Open3.capture3(*gdal_translate_command)
        output_message = "(#{status}) |#{stdout + stderr}| Command: #{gdal_translate_command}"
        self.command_output << "\n#{output_message}"
        self.exit_code = status.to_i
        raise TiffToSqlConversionError.new(output_message) if status.to_i != 0
      end

      def reproject_raster(file)
        gdalwarp_command =[gdalwarp_path, GDALWARP_COMMON_OPTIONS, '-t_srs', "EPSG:#{PROJECTION}", '-of', 'vrt', file, webmercator_filepath].flatten

        stdout, stderr, status  = Open3.capture3(*gdalwarp_command)
        output_message = "(#{status}) |#{stdout + stderr}| Command: #{gdalwarp_command}"
        self.command_output << "\n#{output_message}"
        self.exit_code = status.to_i
        raise TiffToSqlConversionError.new(output_message) if status.to_i != 0
      end

      def align_raster(scale)
        gdalwarp_command = [gdalwarp_path, GDALWARP_COMMON_OPTIONS, '-tr', scale.to_s, "-#{scale}", '-of', 'vrt', webmercator_filepath, aligned_filepath].flatten

        stdout, stderr, status  = Open3.capture3(*gdalwarp_command)
        output_message = "(#{status}) |#{stdout + stderr}| Command: #{gdalwarp_command}"
        self.command_output << "\n#{output_message}"
        self.exit_code = status.to_i
        raise TiffToSqlConversionError.new(output_message) if status.to_i != 0
      end

      def convert_vrt_to_tif
        gdal_translate_command = [gdal_translate_path, GDALTRANSLATE_COMMON_OPTIONS, aligned_filepath, aligned_tif_filepath].flatten

        stdout, stderr, status  = Open3.capture3(*gdal_translate_command)
        output_message = "(#{status}) |#{stdout + stderr}| Command: #{gdal_translate_command}"
        self.command_output << "\n#{output_message}"
        self.exit_code = status.to_i
        raise TiffToSqlConversionError.new(output_message) if status.to_i != 0
      end

      # Returns only X pixel size/scale
      def extract_pixel_size
        output_message = extract_raster_info(webmercator_filepath)
        matches = output_message.match(/pixel size = \((.*)?,/i)
        raise TiffToSqlConversionError.new("Error obtaining raster pixel size: #{output_message}") unless matches[1]
        matches[1].to_f
      end

      def extract_raster_size(filepath=webmercator_filepath)
        output_message = extract_raster_info(filepath)
        matches = output_message.match(/size is (.*)?\n/i)
        raise TiffToSqlConversionError.new("Error obtaining raster size: #{output_message}") unless matches[1]
        matches[1].split(', ')
                  .map{ |value| value.to_i }
      end

      # Returns the raster bands type: Byte, Float64...
      def extract_bands_type
        output_message = extract_raster_info(filepath)
        matches = output_message.scan(/band \d* .* type=(\w*)/i)
        raise TiffToSqlConversionError.new("Error obtaining band field type: #{output_message}") if matches.empty?

        matches.flatten
      end

      def extract_raster_info(file)
        gdalinfo_command = [gdalinfo_path, file]

        stdout, stderr, status  = Open3.capture3(*gdalinfo_command)
        output_message = "(#{status}) |#{stdout + stderr}| Command: #{gdalinfo_command}"
        self.command_output << "\n#{output_message}"
        self.exit_code = status.to_i
        raise TiffToSqlConversionError.new(output_message) if status.to_i != 0

        return output_message
      end

      def run_raster2pgsql(overviews_list)
        command = raster2pgsql_command(overviews_list)

        # TODO: replace comand.join() by other thing as this is insecure to injections attacks
        stdout, stderr, status  = Open3.capture3(command)
        output_message = "(#{status}) |#{stdout + stderr}| Command: #{command}"
        self.command_output << "\n#{output_message}"
        self.exit_code = status.to_i
        raise TiffToSqlConversionError.new(output_message) if status.to_i != 0

        return load_sql_with_psql(raster2psql_filepath)
      end

      def load_sql_with_psql(sql_file)
        command = psql_base_command + ["-f", sql_file]
        
        stdout, stderr, status  = Open3.capture3(*command)
        output_message = "(#{status}) |#{stdout + stderr}| Command: #{command}"
        self.command_output << "\n#{output_message}"
        self.exit_code = status.to_i

        if output_message =~ /canceling statement due to statement timeout/i
          raise StatementTimeoutError.new(output_message, ERRORS_MAP[StatementTimeoutError])
        end

        raise UnknownSridError.new(output_message)          if output_message =~ /invalid srid/i
        raise TiffToSqlConversionError.new(output_message)  if status.to_i != 0
        raise TiffToSqlConversionError.new(output_message)  if output_message =~ /failure/i

        return output_message               
      end

      def calculate_raster_scale(pixel_size)
        z0 = 156543.03515625

        factor = z0 / pixel_size

        pw = Math::log(factor) / Math::log(2)
        pow2 = pw.ceil

        out_scale = z0 / (2 ** pow2)

        out_scale - (out_scale * 0.0001)
      end

      def calculate_raster_overviews(raster_size)
        bigger_size = raster_size.max

        max_power =
          if bigger_size > MAX_REDUCTED_SIZE
            Math::log(bigger_size.to_f / MAX_REDUCTED_SIZE, 2).ceil
          else
            0
          end

        range = (1..max_power + 1)

        overviews = range.map { |x| 2**x }.select { |x| x <= 1000 }

        self.additional_tables = overviews

        overviews.join(',')
      end

      def raster2pgsql_command(overviews_list)
        # Escaping paths to avoid funny injection attacks with "rm -rf /" :-P
        out_file = Shellwords.escape(raster2psql_filepath)
        first_chapter   = %{printf 'SET statement_timeout TO #{statement_timeout};\n' > #{out_file}}
        second_chapter  = %{#{raster2pgsql_path} -s  #{PROJECTION.to_s} -t #{BLOCKSIZE} -C -x -Y -I -f #{RASTER_COLUMN_NAME} \
                          -l #{overviews_list} #{Shellwords.escape(aligned_tif_filepath)} #{Shellwords.escape(SCHEMA + "." + table_name)} >> #{out_file}}
        return first_chapter + " && " + second_chapter
      end

      # We add an overview for the tiler with factor = 1,
      # using the reprojected and adjusted base table. This is done so that the
      # tiler will always use those overviews and never the base table that
      # should be imported without any transformation to avoid
      # reprojection/resampling artifacts in analysis.
      def add_raster_base_overview_for_tiler
        overview_name = OVERLAY_TABLENAME % [1, table_name]
        overview_fqtn = SCHEMA + '.' + overview_name
        queries = [
          %{CREATE TABLE #{overview_fqtn} AS SELECT * FROM #{base_table_fqtn}},
          %{CREATE INDEX ON "#{SCHEMA}"."#{overview_name}" USING gist (st_convexhull("#{RASTER_COLUMN_NAME}"))},
          %{SELECT AddRasterConstraints('#{SCHEMA}', '#{overview_name}','#{RASTER_COLUMN_NAME}',TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,FALSE,TRUE,TRUE,TRUE,TRUE,FALSE)},
          %{SELECT AddOverviewConstraints('#{SCHEMA}', '#{overview_name}'::name, '#{RASTER_COLUMN_NAME}'::name, '#{SCHEMA}', '#{table_name}'::name, '#{RASTER_COLUMN_NAME}'::name, 1)}
        ]
        for query in queries do
          transaction_with_timeout do |db|
            db.run(query)
          end
        end
        @additional_tables = [1] + @additional_tables
      end

      # Import the original raster file without reprojections, adjusting or scales.
      # NOTE: the name of the column the_raster_webmercator is maintained for compatibility.
      def import_original_raster
        transaction_with_timeout do |db|
          db.run %{DROP TABLE #{base_table_fqtn}}
        end
        out_file = Shellwords.escape(raster2psql_original_filepath)
        raster_import_command = %{ printf 'SET statement_timeout TO #{statement_timeout};\n' > #{out_file} && \
                                #{raster2pgsql_path} -t #{BLOCKSIZE} -C -x -Y -I -f #{RASTER_COLUMN_NAME} \
                                #{Shellwords.escape(filepath)} #{Shellwords.escape(SCHEMA + "." + table_name)} >> #{out_file}}

        stdout, stderr, status  = Open3.capture3(raster_import_command)
        output_message = "(#{status}) |#{stdout + stderr}| Command: #{raster_import_command}"
        self.command_output << "\n#{output_message}"
        self.exit_code = status.to_i
        raise TiffToSqlConversionError.new(output_message) if status.to_i != 0
                         
        return load_sql_with_psql(raster2psql_original_filepath)
      end

      def psql_base_command
        host      = pg_options.fetch(:host)
        port      = pg_options.fetch(:port)
        user      = pg_options.fetch(:username)
        database  = pg_options.fetch(:database)

        [psql_path, '-h', host, '-p', port.to_s, '-U', user, '-d', database]
      end

      def raster2pgsql_path
        `which raster2pgsql`.strip
      end

      def psql_path
        `which psql`.strip
      end

      def gdalwarp_path
        `which gdalwarp`.strip
      end

      def gdal_translate_path
        `which gdal_translate`.strip
      end

      def gdalinfo_path
        `which gdalinfo`.strip
      end

    end
  end
end
