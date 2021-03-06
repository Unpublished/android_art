# Copyright (C) 2016 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

.class public LTestCase;
.super Ljava/lang/Object;

# Test that all vregs holding the new-instance are updated after the
# StringFactory call.

## CHECK-START: java.lang.String TestCase.vregAliasing(byte[]) register (after)
## CHECK-DAG:                Return [<<String:l\d+>>]
## CHECK-DAG:     <<String>> InvokeStaticOrDirect  method_name:java.lang.String.<init>

.method public static vregAliasing([B)Ljava/lang/String;
   .registers 5

   # Create new instance of String and store it to v0, v1, v2.
   new-instance v0, Ljava/lang/String;
   move-object v1, v0
   move-object v2, v0

   # Call String.<init> on v1.
   const-string v3, "UTF8"
   invoke-direct {v1, p0, v3}, Ljava/lang/String;-><init>([BLjava/lang/String;)V

   # Return the object from v2.
   return-object v2

.end method

# Test usage of String new-instance before it is initialized.

## CHECK-START: void TestCase.compareNewInstance() register (after)
## CHECK-DAG:     <<Null:l\d+>>   NullConstant
## CHECK-DAG:     <<String:l\d+>> NewInstance
## CHECK-DAG:     <<Cond:z\d+>>   NotEqual [<<String>>,<<Null>>]
## CHECK-DAG:                     If [<<Cond>>]

.method public static compareNewInstance()V
   .registers 3

   new-instance v0, Ljava/lang/String;
   if-nez v0, :return

   # Will throw NullPointerException if this branch is taken.
   const v1, 0x0
   const-string v2, "UTF8"
   invoke-direct {v0, v1, v2}, Ljava/lang/String;-><init>([BLjava/lang/String;)V
   return-void

   :return
   return-void

.end method

# Test deoptimization between String's allocation and initialization. When not
# compiling --debuggable, the NewInstance will be optimized out.

## CHECK-START: int TestCase.deoptimizeNewInstance(int[], byte[]) register (after)
## CHECK:         <<Null:l\d+>>   NullConstant
## CHECK:                         Deoptimize env:[[<<Null>>,{{.*]]}}
## CHECK:                         InvokeStaticOrDirect method_name:java.lang.String.<init>

## CHECK-START-DEBUGGABLE: int TestCase.deoptimizeNewInstance(int[], byte[]) register (after)
## CHECK:         <<String:l\d+>> NewInstance
## CHECK:                         Deoptimize env:[[<<String>>,{{.*]]}}
## CHECK:                         InvokeStaticOrDirect method_name:java.lang.String.<init>

.method public static deoptimizeNewInstance([I[B)I
   .registers 6

   const v2, 0x0
   const v1, 0x1

   new-instance v0, Ljava/lang/String;

   # Deoptimize here if the array is too short.
   aget v1, p0, v1
   add-int/2addr v2, v1

   # Check that we're being executed by the interpreter.
   invoke-static {}, LMain;->assertIsInterpreted()V

   # String allocation should succeed.
   const-string v3, "UTF8"
   invoke-direct {v0, p1, v3}, Ljava/lang/String;-><init>([BLjava/lang/String;)V

   # This ArrayGet will throw ArrayIndexOutOfBoundsException.
   const v1, 0x4
   aget v1, p0, v1
   add-int/2addr v2, v1

   return v2

.end method

# Test that a redundant NewInstance is removed if not used and not compiling
# --debuggable.

## CHECK-START: java.lang.String TestCase.removeNewInstance(byte[]) register (after)
## CHECK-NOT:     NewInstance
## CHECK-NOT:     LoadClass

## CHECK-START-DEBUGGABLE: java.lang.String TestCase.removeNewInstance(byte[]) register (after)
## CHECK:         NewInstance

.method public static removeNewInstance([B)Ljava/lang/String;
   .registers 5

   new-instance v0, Ljava/lang/String;
   const-string v1, "UTF8"
   invoke-direct {v0, p0, v1}, Ljava/lang/String;-><init>([BLjava/lang/String;)V
   return-object v0

.end method

# Test #1 for irreducible loops and String.<init>.
.method public static irreducibleLoopAndStringInit1([BZ)Ljava/lang/String;
   .registers 5

   new-instance v0, Ljava/lang/String;

   # Irreducible loop
   if-eqz p1, :loop_entry
   :loop_header
   const v1, 0x1
   xor-int p1, p1, v1
   :loop_entry
   if-eqz p1, :string_init
   goto :loop_header

   :string_init
   const-string v1, "UTF8"
   invoke-direct {v0, p0, v1}, Ljava/lang/String;-><init>([BLjava/lang/String;)V
   return-object v0

.end method

# Test #2 for irreducible loops and String.<init>.
.method public static irreducibleLoopAndStringInit2([BZ)Ljava/lang/String;
   .registers 5

   new-instance v0, Ljava/lang/String;

   # Irreducible loop
   if-eqz p1, :loop_entry
   :loop_header
   if-eqz p1, :string_init
   :loop_entry
   const v1, 0x1
   xor-int p1, p1, v1
   goto :loop_header

   :string_init
   const-string v1, "UTF8"
   invoke-direct {v0, p0, v1}, Ljava/lang/String;-><init>([BLjava/lang/String;)V
   return-object v0

.end method

# Test #3 for irreducible loops and String.<init> alias.
.method public static irreducibleLoopAndStringInit3([BZ)Ljava/lang/String;
   .registers 5

   new-instance v0, Ljava/lang/String;
   move-object v2, v0

   # Irreducible loop
   if-eqz p1, :loop_entry
   :loop_header
   const v1, 0x1
   xor-int p1, p1, v1
   :loop_entry
   if-eqz p1, :string_init
   goto :loop_header

   :string_init
   const-string v1, "UTF8"
   invoke-direct {v0, p0, v1}, Ljava/lang/String;-><init>([BLjava/lang/String;)V
   return-object v2

.end method
