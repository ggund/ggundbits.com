##
# Ruby 4 compatibility shim for older gems that still call Object#tainted?.
# Liquid 4 (used by Jekyll 3.9) expects this method to exist.
# In modern Ruby, tainting is removed, so we safely define it to always return false.
##

class Object
  unless method_defined?(:tainted?)
    def tainted?
      false
    end
  end
end

