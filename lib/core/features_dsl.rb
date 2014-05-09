module Chequeout::FeaturesDsl
  # == Added to table defintion
  module Schema
    # Delegate DDL actions
    def chequeout(name)
      Chequeout.load
      context.applied_database_scheme[name].each do |code|
        instance_exec &code
      end
    end
  end

  class Feature
    attr_reader :name, :behaviours

    def initialize(name, options = Hash.new, &code)
      # Note we currently ignore the trait option
      @name = name
      @behaviours = Hash.new do |hash, key|
        hash[key] = Array.new
      end
      instance_exec self, &code
    end

    # Push model behaviour
    def behaviour_for(model, options = Hash.new, &code)
      behaviours[model.to_sym].push code
    end

    # Based on model mapping, apply model behaviour
    def apply_to(models, mapping)
      mapping.each do |label, klass|
        behaviours[label].each do |code|
          klass.class_exec models[label], &code
          klass.features << name
        end
      end
    end
  end

  class Model
    attr_reader :name, :context, :behaviours, :database_structures

    def initialize(name, &code)
      @name = name
      @behaviours = [ code ]
      @database_structures = []
    end

    # Record DB structure for migrations
    def database_strcuture(&code)
      database_structures.push code
    end

    # Define extra code to be run
    def code(&code)
      behaviours.push code
    end

    # Resolve a model
    def model(name)
      context.model_mapping[name.to_sym]
    end

    # Run in context for the model
    def apply_to(klass, context)
      @context = context
      behaviours.each do |code|
        klass.class_exec self, &code
      end
    end
  end

  class Context
    module Meta
      def setup(&code)
        setup_actions << code
      end

      def setup_actions
        @setup_actions ||= Set.new
      end

      def features
        @features ||= Set.new
      end
    end

    attr_reader :name, :models, :features, :applied_features, :model_mapping
    def initialize(name, models, features, &code)
      @name             = name
      @models           = models
      @applied          = false
      @features         = features
      @model_mapping    = Hash.new
      @applied_features = Set.new
      instance_exec self, &code
    end

    # Add a model mapping
    def model(name, klass = nil)
      klass ||= name.to_s.classify
      item    = name.to_sym
      context = self
      unless model_mapping[item]
        model_mapping[item] = klass.constantize.tap do |node|
          node.singleton_class.instance_exec do
            include Meta unless is_a? Meta
            define_method :context do
              context
            end
          end
        end
      end
      model_mapping[item]
    end

    # Name a feature to be applied
    def apply_feature(name)
      applied_features << name.to_sym
    end

    def apply!
      raise 'Already applied' if @applied
      model_mapping.each do |name, klass|
        definition = models[name]
        if definition
          definition.apply_to klass, self
        else
          raise 'No model definition for %s' % name
        end
      end
      features.slice(*applied_features).each do |name, items|
        items.each do |feature|
          feature.apply_to models, model_mapping
        end
      end
      model_mapping.values.each do |klass|
        klass.setup_actions.each do |action|
          klass.instance_exec &action
        end
      end
      @applied = true
    end

    # Return schema for active models and featurez
    def applied_database_scheme
      apply unless @applied
      items = models.collect do |name, definition|
        [ name, definition.database_structures ]
      end
      Hash[ items ]
    end
  end

  module Tools
    delegate :[], to: :contexts

    def features
      @features ||= list
    end

    def models
      @models ||= Hash.new
    end

    def contexts
      @contexts ||= Hash.new
    end

    def define_model(name, &code)
      item = name.to_sym
      models[item] = Model.new(item, &code)
    end

    def define_feature(name, &code)
      item = name.to_sym
      features[item].push Feature.new(item, &code)
    end

    def apply(name, &code)
      load
      label = name.to_sym
      contexts[label] = Context.new(label, models, features, &code).tap &:apply!
    end

    def loadable_files
      Dir['%s/lib/{chequeout,traits}/**/*.rb' % base_folder]
    end

    def base_folder
      File.expand_path __FILE__ + '/../../../'
    end

    def load(files = loadable_files)
      files.each { |file| require file }
    end

    def list
      Hash.new do |hash, key|
        hash[key] = Array.new
      end
    end
  end
end
