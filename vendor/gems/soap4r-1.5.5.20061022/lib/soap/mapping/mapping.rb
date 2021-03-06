# SOAP4R - Ruby type mapping utility.
# Copyright (C) 2000, 2001, 2003-2006  NAKAMURA Hiroshi <nahi@ruby-lang.org>.

# This program is copyrighted free software by NAKAMURA, Hiroshi.  You can
# redistribute it and/or modify it under the same terms of Ruby's license;
# either the dual license version in 2003, or any later version.


require 'xsd/codegen/gensupport'


module SOAP


module Mapping
  RubyTypeNamespace = 'http://www.ruby-lang.org/xmlns/ruby/type/1.6'
  RubyTypeInstanceNamespace =
    'http://www.ruby-lang.org/xmlns/ruby/type-instance'
  RubyCustomTypeNamespace = 'http://www.ruby-lang.org/xmlns/ruby/type/custom'
  ApacheSOAPTypeNamespace = 'http://xml.apache.org/xml-soap'


  module TraverseSupport
    def mark_marshalled_obj(obj, soap_obj)
      raise if obj.nil?
      Thread.current[:SOAPMapping][:MarshalKey][obj.__id__] = soap_obj
    end

    def mark_unmarshalled_obj(node, obj)
      return if obj.nil?
      # node.id is not Object#id but SOAPReference#id
      Thread.current[:SOAPMapping][:MarshalKey][node.id] = obj
    end
  end


  EMPTY_OPT = {}.freeze
  def self.obj2soap(obj, registry = nil, type = nil, opt = EMPTY_OPT)
    registry ||= Mapping::DefaultRegistry
    soap_obj = nil
    protect_mapping(opt) do
      soap_obj = _obj2soap(obj, registry, type)
    end
    soap_obj
  end

  def self.soap2obj(node, registry = nil, klass = nil, opt = EMPTY_OPT)
    registry ||= Mapping::DefaultRegistry
    obj = nil
    protect_mapping(opt) do
      obj = _soap2obj(node, registry, klass)
    end
    obj
  end

  def self.ary2soap(ary, type_ns = XSD::Namespace, typename = XSD::AnyTypeLiteral, registry = nil, opt = EMPTY_OPT)
    registry ||= Mapping::DefaultRegistry
    type = XSD::QName.new(type_ns, typename)
    soap_ary = SOAPArray.new(ValueArrayName, 1, type)
    protect_mapping(opt) do
      ary.each do |ele|
        soap_ary.add(_obj2soap(ele, registry, type))
      end
    end
    soap_ary
  end

  def self.ary2md(ary, rank, type_ns = XSD::Namespace, typename = XSD::AnyTypeLiteral, registry = nil, opt = EMPTY_OPT)
    registry ||= Mapping::DefaultRegistry
    type = XSD::QName.new(type_ns, typename)
    md_ary = SOAPArray.new(ValueArrayName, rank, type)
    protect_mapping(opt) do
      add_md_ary(md_ary, ary, [], registry)
    end
    md_ary
  end

  def self.fault2exception(fault, registry = nil)
    registry ||= Mapping::DefaultRegistry
    detail = if fault.detail
        soap2obj(fault.detail, registry) || ""
      else
        ""
      end
    if detail.is_a?(Mapping::SOAPException)
      begin
        e = detail.to_e
	remote_backtrace = e.backtrace
        e.set_backtrace(nil)
        raise e # ruby sets current caller as local backtrace of e => e2.
      rescue Exception => e
	e.set_backtrace(remote_backtrace + e.backtrace[1..-1])
        raise
      end
    else
      fault.detail = detail
      fault.set_backtrace(
        if detail.is_a?(Array)
	  detail
        else
          [detail.to_s]
        end
      )
      raise
    end
  end

  def self._obj2soap(obj, registry, type = nil)
    if referent = Thread.current[:SOAPMapping][:MarshalKey][obj.__id__] and
        !Thread.current[:SOAPMapping][:NoReference]
      SOAPReference.new(referent)
    elsif registry
      registry.obj2soap(obj, type)
    else
      raise MappingError.new("no mapping registry given")
    end
  end

  def self._soap2obj(node, registry, klass = nil)
    if node.nil?
      return nil
    elsif node.is_a?(SOAPReference)
      target = node.__getobj__
      # target.id is not Object#id but SOAPReference#id
      if referent = Thread.current[:SOAPMapping][:MarshalKey][target.id] and
          !Thread.current[:SOAPMapping][:NoReference]
        return referent
      else
        return _soap2obj(target, registry, klass)
      end
    end
    return registry.soap2obj(node, klass)
  end

  if Object.respond_to?(:allocate)
    # ruby/1.7 or later.
    def self.create_empty_object(klass)
      klass.allocate
    end
  else
    MARSHAL_TAG = {
      String => ['"', 1],
      Regexp => ['/', 2],
      Array => ['[', 1],
      Hash => ['{', 1]
    }
    def self.create_empty_object(klass)
      if klass <= Struct
	name = klass.name
	return ::Marshal.load(sprintf("\004\006S:%c%s\000", name.length + 5, name))
      end
      if MARSHAL_TAG.has_key?(klass)
	tag, terminate = MARSHAL_TAG[klass]
	return ::Marshal.load(sprintf("\004\006%s%s", tag, "\000" * terminate))
      end
      MARSHAL_TAG.each do |k, v|
	if klass < k
	  name = klass.name
	  tag, terminate = v
	  return ::Marshal.load(sprintf("\004\006C:%c%s%s%s", name.length + 5, name, tag, "\000" * terminate))
	end
      end
      name = klass.name
      ::Marshal.load(sprintf("\004\006o:%c%s\000", name.length + 5, name))
    end
  end

  # Allow only (Letter | '_') (Letter | Digit | '-' | '_')* here.
  # Caution: '.' is not allowed here.
  # To follow XML spec., it should be NCName.
  #   (denied chars) => .[0-F][0-F]
  #   ex. a.b => a.2eb
  #
  def self.name2elename(name)
    name.gsub(/([^a-zA-Z0-9:_\-]+)/n) {
      '.' << $1.unpack('H2' * $1.size).join('.')
    }.gsub(/::/n, '..')
  end

  def self.elename2name(name)
    name.gsub(/\.\./n, '::').gsub(/((?:\.[0-9a-fA-F]{2})+)/n) {
      [$1.delete('.')].pack('H*')
    }
  end

  def self.const_from_name(name, lenient = false)
    const = ::Object
    name.sub(/\A::/, '').split('::').each do |const_str|
      if XSD::CodeGen::GenSupport.safeconstname?(const_str)
        if const.const_defined?(const_str)
          const = const.const_get(const_str)
          next
        end
      elsif lenient
        const_str = XSD::CodeGen::GenSupport.safeconstname(const_str)
        if const.const_defined?(const_str)
          const = const.const_get(const_str)
          next
        end
      end
      return nil
    end
    const
  end

  def self.class_from_name(name, lenient = false)
    const = const_from_name(name, lenient)
    if const.is_a?(::Class)
      const
    else
      nil
    end
  end

  def self.module_from_name(name, lenient = false)
    const = const_from_name(name, lenient)
    if const.is_a?(::Module)
      const
    else
      nil
    end
  end

  def self.class2qname(klass)
    name = schema_type_definition(klass)
    namespace = schema_ns_definition(klass)
    XSD::QName.new(namespace, name)
  end

  def self.class2element(klass)
    name = schema_type_definition(klass) ||
      Mapping.name2elename(klass.name)
    namespace = schema_ns_definition(klass) || RubyCustomTypeNamespace
    XSD::QName.new(namespace, name)
  end

  def self.obj2element(obj)
    name = namespace = nil
    ivars = obj.instance_variables
    if ivars.include?('@schema_type')
      name = obj.instance_variable_get('@schema_type')
    end
    if ivars.include?('@schema_ns')
      namespace = obj.instance_variable_get('@schema_ns')
    end
    if !name or !namespace
      class2qname(obj.class)
    else
      XSD::QName.new(namespace, name)
    end
  end

  def self.define_singleton_method(obj, name, &block)
    sclass = (class << obj; self; end)
    sclass.class_eval {
      define_method(name, &block)
    }
  end

  def self.get_attributes(obj)
    if obj.is_a?(::Hash)
      obj
    else
      rs = {}
      obj.instance_variables.each do |ele|
        rs[ele.sub(/^@/, '')] = obj.instance_variable_get(ele)
      end
      rs
    end
  end

  def self.get_attributes_for_any(obj, elements)
    if obj.respond_to?(:__xmlele_any)
      obj.__xmlele_any
    else
      any = get_attributes(obj)
      if elements
        elements.each do |child_ele|
          child = get_attribute(obj, child_ele.name.name)
          if k = any.key(child)
            any.delete(k)
          end
        end
      end
      any
    end
  end

  def self.get_attribute(obj, attr_name)
    case obj
    when ::SOAP::Mapping::Object
      return obj[attr_name]
    when ::Hash
      return obj[attr_name] || obj[attr_name.intern]
    else
      iv = obj.instance_variables
      name = XSD::CodeGen::GenSupport.safevarname(attr_name)
      if iv.include?("@#{name}")
        return obj.instance_variable_get("@#{name}")
      elsif iv.include?("@#{attr_name}")
        return obj.instance_variable_get("@#{attr_name}")
      end
      if obj.is_a?(::Struct) or obj.is_a?(Marshallable)
        if obj.respond_to?(name)
          return obj.__send__(name)
        elsif obj.respond_to?(attr_name)
          return obj.__send__(attr_name)
        end
      end
      nil
    end
  end

  def self.set_attributes(obj, values)
    case obj
    when ::SOAP::Mapping::Object
      values.each do |attr_name, value|
        obj.__add_xmlele_value(attr_name, value)
      end
    else
      values.each do |attr_name, value|
        # untaint depends GenSupport.safevarname
        name = XSD::CodeGen::GenSupport.safevarname(attr_name).untaint
        setter = name + "="
        if obj.respond_to?(setter)
          obj.__send__(setter, value)
        else
          obj.instance_variable_set('@' + name, value)
          begin
            unless obj.respond_to?(name)
              obj.instance_eval <<-EOS
                def #{name}
                  @#{name}
                end
              EOS
            end
            unless self.respond_to?(name + "=")
              obj.instance_eval <<-EOS
                def #{name}=(value)
                  @#{name} = value
                end
              EOS
            end
          rescue TypeError
            # singleton class may not exist (e.g. Float)
          end
        end
      end
    end
  end

  def self.schema_ns_definition(klass)
    class_schema_variable(:schema_ns, klass)
  end

  def self.schema_name_definition(klass)
    class_schema_variable(:schema_name, klass)
  end

  def self.schema_type_definition(klass)
    class_schema_variable(:schema_type, klass)
  end

  def self.schema_qualified_definition(klass)
    class_schema_variable(:schema_qualified, klass)
  end

  def self.schema_element_definition(klass)
    class_schema_variable(:schema_element, klass)
  end

  def self.schema_attribute_definition(klass)
    class_schema_variable(:schema_attribute, klass)
  end

  def self.schema_definition_classdef(klass)
    if definition = Thread.current[:SOAPMapping][:SchemaDefinition][klass]
      return definition
    end
    ns = schema_ns_definition(klass)
    name = schema_name_definition(klass)
    type = schema_type_definition(klass)
    qualified = schema_qualified_definition(klass)
    elements = schema_element_definition(klass)
    attributes = schema_attribute_definition(klass)
    return nil if ns.nil? and name.nil? and type.nil? and elements.nil? and attributes.nil?
    definition = create_schema_definition(klass,
      :schema_ns => ns,
      :schema_name => name,
      :schema_type => type,
      :schema_qualified => qualified,
      :schema_element => elements,
      :schema_attribute => attributes
    )
    Thread.current[:SOAPMapping][:SchemaDefinition][klass] = definition
    definition
  end

  def self.create_schema_definition(klass, definition)
    schema_ns = definition[:schema_ns]
    schema_name = definition[:schema_name]
    schema_type = definition[:schema_type]
    schema_qualified = definition[:schema_qualified]
    schema_element = definition[:schema_element]
    schema_attributes = definition[:schema_attribute]
    elename = schema_name ? XSD::QName.new(schema_ns, schema_name) : nil
    type = schema_type ? XSD::QName.new(schema_ns, schema_type) : nil
    definition = SchemaDefinition.new(klass, elename, type, schema_qualified)
    definition.attributes = schema_attributes
    if schema_element
      if schema_element.respond_to?(:is_concrete_definition) and
          schema_element.is_concrete_definition
        definition.elements.replace(schema_element)
      else
        parse_schema_element_definition(klass, definition, schema_element)
      end
    end
    definition
  end

  # for backward compatibility
  def self.parse_schema_element_definition(klass, definition, schema_element)
    if schema_element[0] == :choice
      schema_element.shift
      definition.set_choice
    end
    schema_element.each do |element|
      varname, info = element
      mapped_class_str, elename = info
      as_array = klass.ancestors.include?(::Array)
      if /\[\]$/ =~ mapped_class_str
        mapped_class_str = mapped_class_str.sub(/\[\]$/, '')
        if mapped_class_str.empty?
          mapped_class_str = nil
        end
        as_array = true
      end
      if mapped_class_str
        mapped_class = Mapping.class_from_name(mapped_class_str)
        if mapped_class.nil?
          warn("cannot find mapped class: #{mapped_class_str}")
        end
      end
      if elename == XSD::AnyTypeName
        definition.set_any
      elsif elename.nil?
        ns ||= definition.elename.namespace if definition.elename
        ns ||= definition.type.namespace if definition.type
        elename = XSD::QName.new(ns, varname)
      end
      definition.elements <<
        SchemaElementDefinition.new(varname, mapped_class, elename, as_array)
    end
  end

  class SchemaElementDefinition
    attr_reader :varname, :mapped_class, :elename

    def initialize(varname, mapped_class, elename, as_array)
      @varname = varname
      @mapped_class = mapped_class
      @elename = elename
      @as_array = as_array
    end

    def as_array?
      @as_array
    end

    def is_concrete_definition
      true
    end
  end

  class SchemaElementChoiceDefinition < ::Array
    def is_concrete_definition
      true
    end
  end

  class SchemaDefinition
    attr_reader :class_for
    attr_reader :elename, :type
    attr_reader :qualified, :elements
    attr_accessor :attributes

    def initialize(class_for, elename, type, qualified)
      @class_for = class_for
      @elename = elename
      @type = type
      @qualified = qualified
      @elements = []
      @attributes = nil
      @choice = false
      @any = false
    end

    def choice?
      @choice
    end

    def have_any?
      @any
    end

    def set_choice
      @choice = true
    end

    def set_any
      @any = true
    end
  end

  class << Mapping
  private

    def class_schema_variable(sym, klass)
      var = "@@#{sym}"
      klass.class_variables.include?(var) ? klass.class_eval(var) : nil
    end

    def protect_mapping(opt)
      protect_threadvars(:SOAPMapping) do
        data = Thread.current[:SOAPMapping] = {}
        data[:MarshalKey] = {}
        data[:ExternalCES] = opt[:external_ces] || XSD::Charset.encoding
        data[:NoReference] = opt[:no_reference]
        data[:SchemaDefinition] = {}
        yield
      end
    end

    def protect_threadvars(*symbols)
      backup = {}
      begin
        symbols.each do |sym|
          backup[sym] = Thread.current[sym]
        end
        yield
      ensure
        symbols.each do |sym|
          Thread.current[sym] = backup[sym]
        end
      end
    end

    def add_md_ary(md_ary, ary, indices, registry)
      for idx in 0..(ary.size - 1)
        if ary[idx].is_a?(Array)
          add_md_ary(md_ary, ary[idx], indices + [idx], registry)
        else
          md_ary[*(indices + [idx])] = _obj2soap(ary[idx], registry)
        end
      end
    end
  end
end


end
