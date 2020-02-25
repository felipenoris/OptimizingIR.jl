
# API Reference

## Public API

```@docs
OptimizingIR.Op
OptimizingIR.Variable
OptimizingIR.call
OptimizingIR.addinstruction!
OptimizingIR.addinput!
OptimizingIR.addoutput!
OptimizingIR.callgetindex
OptimizingIR.callsetindex
OptimizingIR.assign!
OptimizingIR.constant
```

## Internals

```@docs
OptimizingIR.AbstractValue
OptimizingIR.PureInstruction
OptimizingIR.ImpureInstruction
OptimizingIR.compile
OptimizingIR.SSAValue
OptimizingIR.try_on_add_instruction_passes
OptimizingIR.LookupTable
OptimizingIR.Const
OptimizingIR.OptimizationRule
```
