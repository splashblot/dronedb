Sequel.migration do
  change do
    create_table :devices do
      foreign_key :user_id, :users, type: 'uuid', null: false, on_delete: :cascade, primary_key: true

      Uuid :id, default: 'uuid_generate_v4()'.lit

      String :devices, null: false, type: 'json', default: '{}'

      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    alter_table :devices do
      add_index :user_id
    end
  end

  down do
    alter_table :devices do
      drop_index :user_id
    end

    drop_table :devices
  end
end
