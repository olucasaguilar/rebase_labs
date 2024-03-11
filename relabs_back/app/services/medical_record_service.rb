module MedicalRecordService
  class ImportCSV
    require 'csv'
    require_relative '../../db/database_connection'

    DIACRITICS = [*0x1DC0..0x1DFF, *0x0300..0x036F, *0xFE20..0xFE2F].pack('U*')

    def self.import(csv_path, reset_table = false)
      @db_conn = DatabaseConnection.new
      @csv_path = csv_path
      drop_table if reset_table && table_exists?
      set_table_attributes
      create_table unless table_exists?
      prepare_dataset
      insert_into_database
    end

    class << self
      private

      def table_exists?
        query = <<~SQL
          SELECT EXISTS (
            SELECT 1
            FROM pg_tables
            WHERE schemaname = 'public'
            AND tablename = 'medical_record'
          )
        SQL

        query_return = @db_conn.exec(query)

        query_return[0]['exists'] == 't'
      end

      def drop_table
        @db_conn.exec('DROP TABLE IF EXISTS medical_record')
      end

      def create_table
        attribute_definitions = @attributes.map { |attr| "#{attr} VARCHAR" }.join(", ")
      
        create_table_query = <<~SQL 
          CREATE TABLE medical_record (#{attribute_definitions})
        SQL
      
        @db_conn.exec(create_table_query)
      end

      def set_table_attributes
        csv_attributes = CSV.read(@csv_path, col_sep: ';')[0]
        @attributes = csv_attributes.map { |attr| serialize_attribute(attr) }
      end
      
      def serialize_attribute(str)
        str
          .unicode_normalize(:nfd)
          .tr(DIACRITICS, '')
          .unicode_normalize(:nfc)
          .gsub(/[^a-zA-Z0-9]/, '_')
      end

      def prepare_dataset
        csv_patients = CSV.read(@csv_path, col_sep: ';')[1..]
      
        @converted_values = csv_patients.map do |patient|
          patient.map { |attr| "\'#{serialize_values(attr)}\'" }.join(',')
        end.join('), (')
      end
      
      def serialize_values(str)
        str
          .gsub(/'/, "''")
      end

      def insert_into_database
        @db_conn.exec("INSERT INTO medical_record (#{@attributes.join(', ')}) VALUES (#{@converted_values})")
      end
    end
  end
end