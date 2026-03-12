class Object
  unless method_defined?(:tainted?)
    def tainted?
      false
    end
  end
end

