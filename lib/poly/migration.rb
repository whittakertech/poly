# frozen_string_literal: true

module Poly::Migration
  # Table-builder helper (create_table/change_table):
  #   poly_resource t, :resource
  # Direct helper (add_column style):
  #   poly_resource :coins, :resource
  def poly_resource(table_or_builder, name, null: true, id_type: :string)
    if table_builder?(table_or_builder)
      table_or_builder.references name, polymorphic: true, null: null, type: id_type
    else
      add_column table_or_builder, :"#{name}_type", :string, null: null
      add_column table_or_builder, :"#{name}_id", id_type, null: null
    end
  end

  # Table-builder helper (create_table/change_table):
  #   poly_role t, :resource
  # Direct helper (add_column style):
  #   poly_role :coins, :resource
  def poly_role(table_or_builder, name, null: true)
    if table_builder?(table_or_builder)
      table_or_builder.string :"#{name}_role", null: null
    else
      add_column table_or_builder, :"#{name}_role", :string, null: null
    end
  end

  # Table-builder helper (create_table/change_table):
  #   poly_owner t
  # Direct helper (add_column style):
  #   poly_owner :coins
  def poly_owner(table_or_builder, type_column: :owner_type, id_column: :owner_id, id_type: :string, null: true)
    if table_builder?(table_or_builder)
      table_or_builder.string type_column, null: null
      table_or_builder.public_send(id_type, id_column, null: null)
    else
      add_column table_or_builder, type_column, :string, null: null
      add_column table_or_builder, id_column, id_type, null: null
    end
  end

  def poly_resource_index(table, name, unique: false)
    add_index table, [:"#{name}_type", :"#{name}_id"], unique: unique
  end

  def poly_owner_index(table, type_column: :owner_type, id_column: :owner_id, unique: false)
    add_index table, [type_column, id_column], unique: unique
  end

  private

  def table_builder?(value)
    value.respond_to?(:references)
  end
end
