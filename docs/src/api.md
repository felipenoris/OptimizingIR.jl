
# API Reference

## Public API

```@docs
OptimizingIR.Op
OptimizingIR.Variable
OptimizingIR.call
OptimizingIR.addinstruction!
OptimizingIR.addinput!
OptimizingIR.addoutput!
OptimizingIR.assign!
OptimizingIR.constant
OptimizingIR.compile
OptimizingIR.has_symbol
OptimizingIR.generate_unique_variable_symbol
```

## Internals

```@docs
OptimizingIR.AbstractValue
OptimizingIR.PureInstruction
OptimizingIR.ImpureInstruction
OptimizingIR.SSAValue
OptimizingIR.try_on_add_instruction_passes
OptimizingIR.LookupTable
OptimizingIR.Const
OptimizingIR.OptimizationRule
OptimizingIR.BasicBlockInterpreter
OptimizingIR.Native
```
