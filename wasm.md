WASM State and Semantics
========================

```k
require "data.k"

module WASM
    imports WASM-DATA
```

Configuration
-------------

```k
    configuration
      <k> $PGM:Instrs </k>
      <stack> .Stack </stack>
      <curFrame>
        <addrs>   .Map </addrs>
        <locals>  .Map </locals>
        <globals> .Map </globals>
      </curFrame>
      <store>
        <funcs>
          <funcDef multiplicity="*" type="Map">
            <fname>  0              </fname>
            <fcode>  .Instrs:Instrs </fcode>
            <ftype>  .Type          </ftype>
            <flocal> .Type          </flocal>
            <faddrs> .Map           </faddrs>
          </funcDef>
        </funcs>
      </store>
```

Instructions
------------

### Sequencing

WASM instructions are space-separated lists of instructions.

```k
    syntax Instrs ::= List{Instr, ""}
 // ---------------------------------
    rule <k> .Instrs                       => .             ... </k>
    rule <k> I:Instr IS:Instrs             => I ~> IS       ... </k>
    rule <k> I:Instr ~> .Instrs            => I             ... </k>
    rule <k> I:Instr ~> I':Instr IS:Instrs => I ~> I' ~> IS ... </k>
```

### Traps

When a single value ends up on the instruction stack (the `<k>` cell), it is moved over to the value stack (the `<stack>` cell).
If the value is the special `undefined`, then `trap` is generated instead.

```k
    syntax Instr ::= "trap"
 // -----------------------
    rule <k> undefined => trap ... </k>
    rule <k> V:Val     => .    ... </k>
         <stack> STACK => V : STACK </stack>
      requires V =/=K undefined
```

Numeric Operators
-----------------

A large portion of the available opcodes are pure arithmetic.
This allows us to give purely functional semantics to many numeric opcodes.

### Constants

Constants are moved directly to the value stack.
Function `#unsigned` is called on integers to allow programs to use negative numbers directly.

```k
    syntax Instr ::= "(" IValType "." "const" Int   ")"
                   | "(" FValType "." "const" Float ")"
 // ---------------------------------------------------
    rule <k> ( ITYPE:IValType . const VAL ) => < ITYPE > #unsigned(ITYPE, VAL) ... </k>
    rule <k> ( FTYPE:FValType . const VAL ) => < FTYPE > VAL                   ... </k>
```

### Unary Operators

When a unary operator is the next instruction, the single argument is loaded from the `<stack>` automatically.

```k
    syntax UnOp ::= IUnOp
 // ---------------------

    syntax Instr ::= "(" IValType "." IUnOp       ")"
                   | "(" IValType "." IUnOp Instr ")"
                   | IValType "." IUnOp Int
 // ---------------------------------------
    rule <k> ( ITYPE . UOP:IUnOp I:Instr ) => I ~> ( ITYPE . UOP ) ... </k>

    rule <k> ( ITYPE . UOP:IUnOp ) => ITYPE . UOP SI1 ... </k>
         <stack> < ITYPE > SI1 : STACK => STACK </stack>
```

### Binary Operators

When a binary operator is the next instruction, the two arguments are loaded from the `<stack>` automatically.

```k
    syntax BinOp ::= IBinOp
 // -----------------------

    syntax Instr ::= "(" IValType "." IBinOp             ")"
                   | "(" IValType "." IBinOp Instr Instr ")"
                   | IValType "." IBinOp Int Int
 // --------------------------------------------
    rule <k> ( ITYPE . BOP:IBinOp I:Instr I':Instr ) => I' ~> I ~> ( ITYPE . BOP ) ... </k>

    rule <k> ( ITYPE . BOP:IBinOp ) => ITYPE . BOP SI1 SI2 ... </k>
         <stack> < ITYPE > SI1 : < ITYPE > SI2 : STACK => STACK </stack>
```

### Integer Arithmetic

`add`, `sub`, and `mul` are given semantics by lifting the correct K operators through the `#chop` function.

```k
    syntax IBinOp ::= "add" | "sub" | "mul"
 // ---------------------------------------
    rule <k> ITYPE . add I1 I2 => #chop(< ITYPE > I1 +Int I2) ... </k>
    rule <k> ITYPE . sub I1 I2 => #chop(< ITYPE > I1 -Int I2) ... </k>
    rule <k> ITYPE . mul I1 I2 => #chop(< ITYPE > I1 *Int I2) ... </k>
```

`div_*` and `rem_*` have extra side-conditions about when they are defined or not.
Note that we do not need to call `#chop` on the results here.

```k
    syntax IBinOp ::= "div_u" | "rem_u"
 // -----------------------------------
    rule <k> ITYPE . div_u I1 I2 => #if I2 =/=Int 0 #then < ITYPE > (I1 /Int I2) #else undefined #fi ... </k>
    rule <k> ITYPE . rem_u I1 I2 => #if I2 =/=Int 0 #then < ITYPE > (I1 %Int I2) #else undefined #fi ... </k>

    syntax IBinOp ::= "div_s" | "rem_s"
 // -----------------------------------
    rule <k> ITYPE . div_s I1 I2
          => #if I2 =/=Int 0 andBool (I1 =/=Int #pow1(ITYPE) orBool (I2 =/=Int #pow(ITYPE) -Int 1))
                #then < ITYPE > #unsigned(ITYPE, #signed(ITYPE, I1) /Int #signed(ITYPE, I2))
                #else undefined
             #fi
         ...
         </k>

    rule <k> ITYPE . rem_s I1 I2
          => #if I2 =/=Int 0
                #then < ITYPE > #unsigned(ITYPE, #signed(ITYPE, I1) %Int #signed(ITYPE, I2))
                #else undefined
             #fi
         ...
         </k>
```

### Bitwise Operations

Of the bitwise operators, `and` will not overflow, but `or` and `xor` could.
These simply are the lifted K operators.

```k
    syntax IBinOp ::= "and" | "or" | "xor"
 // --------------------------------------
    rule <k> ITYPE . and I1 I2 =>       < ITYPE > I1 &Int   I2  ... </k>
    rule <k> ITYPE . or  I1 I2 => #chop(< ITYPE > I1 |Int   I2) ... </k>
    rule <k> ITYPE . xor I1 I2 => #chop(< ITYPE > I1 xorInt I2) ... </k>
```

Similarly, K bitwise shift operators are lifted for `shl` and `shr_u`.
Careful attention is made for the signed version `shr_s`.

```k
    syntax IBinOp ::= "shl" | "shr_u" | "shr_s"
 // -------------------------------------------
    rule <k> ITYPE . shl   I1 I2 => #chop(< ITYPE > I1 <<Int (I2 %Int #width(ITYPE))) ... </k>
    rule <k> ITYPE . shr_u I1 I2 =>       < ITYPE > I1 >>Int (I2 %Int #width(ITYPE))  ... </k>

    rule <k> ITYPE . shr_s I1 I2 => < ITYPE > #unsigned(ITYPE, #signed(ITYPE, I1) >>Int (I2 %Int #width(ITYPE))) ... </k>
```

The rotation operators `rotl` and `rotr` do not have appropriate K builtins, and so are built with a series of shifts.

```k
    syntax IBinOp ::= "rotl" | "rotr"
 // ---------------------------------
    rule <k> ITYPE . rotl I1 I2 => #chop(< ITYPE > (I1 <<Int (I2 %Int #width(ITYPE))) +Int (I1 >>Int (#width(ITYPE) -Int (I2 %Int #width(ITYPE))))) ... </k>
    rule <k> ITYPE . rotr I1 I2 => #chop(< ITYPE > (I1 >>Int (I2 %Int #width(ITYPE))) +Int (I1 <<Int (#width(ITYPE) -Int (I2 %Int #width(ITYPE))))) ... </k>
```

**TODO**: `clz`, `ctz`, `popcnt`.

### Comparison Operations

All of the following opcodes are liftings of the K builtin operators using the helper `#bool`.

```k
    syntax IUnOp ::= "eqz"
 // ----------------------
    rule <k> ITYPE . eqz I1 => < ITYPE > #bool(I1 ==Int 0) ... </k>

    syntax IBinOp ::= "eq" | "ne"
 // -----------------------------
    rule <k> ITYPE . eq I1 I2 => < ITYPE > #bool(I1  ==Int I2) ... </k>
    rule <k> ITYPE . ne I1 I2 => < ITYPE > #bool(I1 =/=Int I2) ... </k>

    syntax IBinOp ::= "lt_u" | "gt_u" | "lt_s" | "gt_s"
 // ---------------------------------------------------
    rule <k> ITYPE . lt_u I1 I2 => < ITYPE > #bool(I1 <Int I2) ... </k>
    rule <k> ITYPE . gt_u I1 I2 => < ITYPE > #bool(I1 >Int I2) ... </k>

    rule <k> ITYPE . lt_s I1 I2 => < ITYPE > #bool(#signed(ITYPE, I1) <Int #signed(ITYPE, I2)) ... </k>
    rule <k> ITYPE . gt_s I1 I2 => < ITYPE > #bool(#signed(ITYPE, I1) >Int #signed(ITYPE, I2)) ... </k>

    syntax IBinOp ::= "le_u" | "ge_u" | "le_s" | "ge_s"
 // ---------------------------------------------------
    rule <k> ITYPE . le_u I1 I2 => < ITYPE > #bool(I1 <=Int I2) ... </k>
    rule <k> ITYPE . ge_u I1 I2 => < ITYPE > #bool(I1 >=Int I2) ... </k>

    rule <k> ITYPE . le_s I1 I2 => < ITYPE > #bool(#signed(ITYPE, I1) <=Int #signed(ITYPE, I2)) ... </k>
    rule <k> ITYPE . ge_s I1 I2 => < ITYPE > #bool(#signed(ITYPE, I1) >=Int #signed(ITYPE, I2)) ... </k>
```

Stack Operations
----------------

Operator `drop` removes a single item from the `<stack>`.
The `select` operator picks one of the second or third stack values based on the first.

```k
    syntax Instr ::= "drop"
 // -----------------------
    rule <k> drop => . ... </k> <stack> S1 : STACK => STACK </stack>

    syntax Instr ::= "select"
 // -------------------------
    rule <k> select => . ... </k>
         <stack> < i32 > C : < TYPE > V1:Number : < TYPE > V2:Number : STACK
              => < TYPE > #if C =/=Int 0 #then V1 #else V2 #fi       : STACK
         </stack>
```

Structured Control Flow
-----------------------

`nop` does nothing.

```k
    syntax Instr ::= "nop"
 // ----------------------
    rule <k> nop => . ... </k>
```

Labels are administrative instructions used to mark the targets of break instructions.
They contain the continuation to use following the label, as well as the original stack to restore.
The supplied type represents the values that should taken from the current stack.

A block is the simplest way to create targets for break instructions (ie. jump destinations).
It simply executes the block then records a label with an empty continuation.

```k
    syntax Label ::= "label" VecType "{" Instrs "}" Stack
 // -----------------------------------------------------
    rule <k> label [ TYPES ] { IS } STACK' => IS ... </k>
         <stack> STACK => #take(TYPES, STACK) ++ STACK' </stack>

    syntax Instr ::= "(" "block" FuncDecls Instrs ")"
                   | "block" VecType Instrs "end"
 // ---------------------------------------------
    rule <k> ( block FDECLS:FuncDecls INSTRS:Instrs )
          => block gatherTypes(result, FDECLS) INSTRS end
         ...
         </k>

    rule <k> block VTYPE IS end => IS ~> label VTYPE { .Instrs } STACK ... </k>
         <stack> STACK => .Stack </stack>
```

The `br*` instructions search through the instruction stack (the `<k>` cell) for the correct label index.
Upon reaching it, the label itself is executed.

Note that, unlike in the WASM specification document, we do not need the special "context" operator here because the value and instruction stacks are separate.

```k
    syntax Instr ::= "br" Int
 // -------------------------
    rule <k> br N ~> (I:Instr => .) ... </k>
    rule <k> br N ~> L:Label => #if N ==Int 0 #then L #else br (N -Int 1) #fi ... </k>

    syntax Instr ::= "br_if" Int
 // ----------------------------
    rule <k> br_if N => #if VAL =/=Int 0 #then br N #else .K #fi ... </k>
         <stack> < TYPE > VAL : STACK => STACK </stack>
```

Finally, we have the conditional and loop instructions.

```k
    syntax Instr ::= "if" VecType Instrs "else" Instrs "end"
 // --------------------------------------------------------
    rule <k> if VTYPE IS else IS' end
          => #if VAL =/=Int 0 #then IS #else IS' #fi
          ~> label VTYPE { .Instrs } STACK
         ...
         </k>
         <stack> < i32 > VAL : STACK => .Stack </stack>

    syntax Instr ::= "loop" VecType Instrs "end"
 // --------------------------------------------
    rule <k> loop VTYPE IS end => IS ~> label [ .ValTypes ] { loop VTYPE IS end } STACK ... </k>
         <stack> STACK => .Stack </stack>
```

Memory Operators
----------------

### Locals

The various `init_local` variants assist in setting up the `locals` cell.

```k
    syntax Instr ::=  "init_local"  Int Val
                   |  "init_locals"     Stack
                   | "#init_locals" Int Stack
 // -----------------------------------------
    rule <k> init_local INDEX VALUE => . ... </k>
         <locals> LOCALS => LOCALS [ INDEX <- VALUE ] </locals>

    rule <k> init_locals VALUES => #init_locals 0 VALUES ... </k>

    rule <k> #init_locals _ .Stack => . ... </k>
    rule <k> #init_locals N (VALUE : STACK)
          => init_local N VALUE
          ~> #init_locals (N +Int 1) STACK
          ...
          </k>
```

The `*_local` instructions are defined here.

```k
    syntax Instr ::= "get_local" Int
                   | "set_local" Int
                   | "tee_local" Int
 // --------------------------------
    rule <k> get_local INDEX => . ... </k>
         <stack> STACK => VALUE : STACK </stack>
         <locals> ... INDEX |-> VALUE ... </locals>

    rule <k> set_local INDEX => . ... </k>
         <stack> VALUE : STACK => STACK </stack>
         <locals> ... INDEX |-> (_ => VALUE) ... </locals>

    rule <k> tee_local INDEX => . ... </k>
         <stack> VALUE : STACK </stack>
         <locals> ... INDEX |-> (_ => VALUE) ... </locals>
```

### Globals

```k
    syntax Instr ::= "init_global" Int Val
                   |  "get_global" Int
                   |  "set_global" Int
 // ----------------------------------
    rule <k> init_global INDEX VALUE => . ... </k>
         <globals> GLOBALS => GLOBALS [ INDEX <- VALUE ] </globals>

    rule <k> get_global INDEX => . ... </k>
         <stack> STACK => VALUE : STACK </stack>
         <globals> ... INDEX |-> VALUE ... </globals>

    rule <k> set_global INDEX => . ... </k>
         <stack> VALUE : STACK => STACK </stack>
         <globals> ... INDEX |-> (_ => VALUE) ... </globals>
```

Function Declaration and Invocation
-----------------------------------

### Function Declaration

Function declarations can look quite different depending on which fields are ommitted and what the context is.
Here, we allow for an "abstract" function declaration using syntax `func_::___`, and a more concrete one which allows arbitrary order of declaration of parameters, locals, and results.

```k
    syntax FunctionName ::= Int | String | Identifier
 // -------------------------------------------------

    syntax TypeKeyWord ::= "param" | "result" | "local"
 // ---------------------------------------------------

    syntax FuncDecl  ::= "(" FuncDecl ")"     [bracket]
                       | TypeKeyWord ValTypes
                       | "export" FunctionName
    syntax FuncDecls ::= List{FuncDecl, ""}
 // ---------------------------------------

    syntax Instr ::= "(" "func"              FuncDecls Instrs ")"
                   | "(" "func" FunctionName FuncDecls Instrs ")"
                   | "func" FunctionName "::" FuncType VecType "{" Instrs "}"
 // -------------------------------------------------------------------------
    rule <k> ( func FDECLS INSTRS )
          => func gatherExportedName(FDECLS) :: gatherFuncType(FDECLS) gatherTypes(local, FDECLS) { INSTRS }
         ...
         </k>

    rule <k> ( func FNAME FDECLS INSTRS )
          => func FNAME :: gatherFuncType(FDECLS) gatherTypes(local, FDECLS) { INSTRS }
         ...
         </k>

    rule <k> func FNAME :: FTYPE LTYPE { INSTRS } => . ... </k>
         <funcs>
           ( .Bag
          => <funcDef>
               <fname>  FNAME  </fname>
               <fcode>  INSTRS </fcode>
               <ftype>  FTYPE  </ftype>
               <flocal> LTYPE  </flocal>
               ...
             </funcDef>
           )
           ...
         </funcs>

    syntax FunctionName ::= gatherExportedName ( FuncDecls ) [function]
 // -------------------------------------------------------------------
    rule gatherExportedName(export FNAME   FDECLS:FuncDecls) => FNAME
    rule gatherExportedName(FDECL:FuncDecl FDECLS:FuncDecls) => gatherExportedName(FDECLS) [owise]

    syntax FuncType ::= gatherFuncType ( FuncDecls ) [function]
 // -----------------------------------------------------------
    rule gatherFuncType(FDECLS) => gatherTypes(param, FDECLS) -> gatherTypes(result, FDECLS)

    syntax VecType ::=  gatherTypes ( TypeKeyWord , FuncDecls )            [function]
                     | #gatherTypes ( TypeKeyWord , FuncDecls , ValTypes ) [function]
 // ---------------------------------------------------------------------------------
    rule gatherTypes(TKW, FDECLS) => #gatherTypes(TKW, FDECLS, .ValTypes)

    rule #gatherTypes(TKW , .FuncDecls            , TYPES) => [ TYPES ]
    rule #gatherTypes(TKW , FDECL:FuncDecl FDECLS , TYPES) => #gatherTypes(TKW, FDECLS, TYPES) [owise]

    rule #gatherTypes(TKW , TKW VTYPES' FDECLS:FuncDecls , VTYPES)
      => #gatherTypes(TKW ,             FDECLS           , VTYPES + VTYPES')
```

### Function Invocation/Return

Frames are used to store function return points.
Similar to labels, they sit on the instruction stack (the `<k>` cell), and `return` consumes things following it until hitting it.
Unlike labels, only one frame can be "broken" through at a time.

```k
    syntax Frame ::= "frame" ValTypes Stack Map
 // -------------------------------------------
    rule <k> frame TRANGE STACK' LOCAL' => . ... </k>
         <stack> STACK => #take(TRANGE, STACK) ++ STACK' </stack>
         <locals> _ => LOCAL' </locals>

    syntax Instr ::= "invoke" FunctionName
 // --------------------------------------
    rule <k> invoke FNAME
          => init_locals #take(TDOMAIN, STACK) ++ #zero(TLOCALS)
          ~> INSTRS
          ~> frame TRANGE #drop(TDOMAIN, STACK) LOCAL
          ...
          </k>
         <stack>  STACK => .Stack </stack>
         <curFrame>
           <addrs> _ => ADDRS </addrs>
           <locals> LOCAL => .Map </locals>
           ...
         </curFrame>
         <funcDef>
           <fname>  FNAME                     </fname>
           <fcode>  INSTRS                    </fcode>
           <ftype>  [ TDOMAIN ] -> [ TRANGE ] </ftype>
           <flocal> [ TLOCALS ]               </flocal>
           <faddrs> ADDRS                     </faddrs>
           ...
         </funcDef>

    syntax Instr ::= "return"
 // -------------------------
    rule <k> return ~> (I:Instr => .)  ... </k>
    rule <k> return ~> (L:Label => .)  ... </k>
    rule <k> (return => .) ~> FR:Frame ... </k>
```

Module Declaration
------------------

Currently, we support a single module.
The surronding `module` tag is discarded, and the inner portions are run like they are instructions.

```k
    syntax Instr ::= "(" "module" Instrs ")"
 // ----------------------------------------
    rule <k> ( module INSTRS ) => INSTRS ... </k>
```

```k
endmodule
```
