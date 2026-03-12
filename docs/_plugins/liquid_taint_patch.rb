require "liquid"

# Ruby 4 removed Object#tainted?, but older Liquid versions still call
# Variable#taint_check. Newer Liquid calls this with two arguments
# (context, obj). We accept any arguments and no-op the check so Jekyll
# can run on modern Ruby.
module LiquidTaintPatch
  def taint_check(*_args)
    # Intentionally do nothing on modern Ruby / Liquid
  end
end

Liquid::Variable.prepend(LiquidTaintPatch)

