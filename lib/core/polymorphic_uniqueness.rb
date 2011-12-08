module PolymorphicUniqueness
  # Used for joins
  def validates_relations_polymorphic_uniqueness_of(polymorph, other)
    poly_type = ('%s_type' % polymorph).to_sym
    poly_pk   = ('%s_id'   % polymorph).to_sym
    other_pk  = ('%s_id'   % other).to_sym
    with_options :allow_nil => true do |__|
      __.validates poly_pk, :uniqueness => { :scope => [ other_pk, poly_type ] }
      __.validates other_pk, :uniqueness => { :scope => [ poly_pk, poly_type ] }
      __.validates poly_type, :uniqueness => { :scope => [ other_pk, poly_pk ] }
    end
  end
end

ActiveRecord::Base.extend PolymorphicUniqueness
