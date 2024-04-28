/*
    Copyright 2018 0KIMS association.

    This file is part of circom (Zero Knowledge Circuit Compiler).

    circom is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    circom is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with circom. If not, see <https://www.gnu.org/licenses/>.
*/
pragma circom 2.1.5;

include "bitify.circom";
include "escalarmul/escalarmulfix.circom";

// The templates and functions of this file only work for prime field bn128 (21888242871839275222246405745257275088548364400416034343698204186575808495617)


/*
*** BabyAdd(): template that receives two points of the Baby Jubjub curve in Edwards form and returns the addition of the points.
        - Inputs: p1 = (p1.x, p1.y) -> two field values representing a point of the curve in Edwards form
                  p2 = (p2.x, p2.y) -> two field values representing a point of the curve in Edwards form
        - Outputs: pout = (pout.x, pout.y) -> two field values representing a point of the curve in Edwards form, pout = p1 + p2
         
    Example:
    
    tau = d * p1.x * p2.x * p1.y * p2.y
    
    
                          p1.x * p2.y + p1.y * p2.x     p1.y * p2.y - p1.x * p2.x
    [pout.x, pout.y] = [ --------------------------- , --------------------------- ]
                                 1 + d * tau                   1 - d * tau     
    
*/

bus Point {
    signal {bn128} x,y;
}

template BabyAdd() {
    Point input {babyedwards} p1,p2;
    Point output {babyedwards} pout;

    signal beta;
    signal gamma;
    signal delta;
    signal tau;

    var a = 168700;
    var d = 168696;

    beta <== p1.x*p2.y;
    gamma <== p1.y*p2.x;
    delta <== (-a*p1.x + p1.y)*(p2.x + p2.y);
    tau <== beta * gamma;

    pout.x <-- (beta + gamma) / (1 + d*tau);
    (1 + d*tau) * pout.x === (beta + gamma);

    pout.y <-- (delta + a*beta - gamma) / (1 - d*tau);
    (1 - d*tau)*pout.y === (delta + a*beta - gamma);
}



/*
*** BabyDouble(): template that receives a point pin of the Baby Jubjub curve in Edwards form and returns the point 2 * pin.
        - Inputs: pin = (pin.x, pin.y) -> two field values representing a point of the curve in Edwards form
        - Outputs: pout = (pout.x, pout.y) -> two field values representing a point of the curve in Edwards form, 2 * pin = pout
         
    Example: BabyDouble()(p) = BabyAdd()(p, p)
    
*/

template BabyDbl() {
    Point input {babyedwards} pin;
    Point output {babyedwards} pout;

    component adder = BabyAdd();
    adder.p1 <== pin;
    adder.p2 <== pin;

    adder.pout ==> pout;
}


/*
*** BabyCheck(): template that receives an input point pin = (pin.x, pin.y) and checks if it belongs to the Baby Jubjub curve.
        - Inputs: pin = (pin.x, pin.y) -> two field values representing the point that we want to check
        - Outputs: pout = (pout.x, pout.y) -> two field values representing the same point as the input but with the babyedwards tag
                                              to point out it is a point of the Baby Jubjub curve in Edwards form
        
    Example: The set of solutions of BabyCheck()(p) are the points of the Baby Jubjub curve in Edwards form
    
*/


template BabyCheck() {
    Point input pin;
    Point output {babyedwards} pout;

    // Point p2;
    signal x2;
    signal y2;

    var a = 168700;
    var d = 168696;

    x2 <== pin.x*pin.x; //x2 = pin.x^2
    y2 <== pin.y*pin.y; //y2 = pin.y^2
    
    a*x2 + y2 === 1 + d*x2*y2;
    
    pout <== pin; 
}


/*
*** BabyPbk(): template that receives an input in representing a value in the prime subgroup with order r = 2736030358979909402780800718157159386076813972158567259200215660948447373041,
               and returns the point of the BabyJubjub curve in * P with P being the point P = (5299619240641551281634865583518297030282874472190772894086521144482721001553, 16950150798460657717958625567821834550301663161624707787222815936182638968203)

This template is used to extract the public key from the private key.
        - Inputs: in -> field value in [1,r-1]
        - Outputs: A = (A.x, A.y) -> two field values representing a point of the curve in Edwards form, in * P = A
    
*/

template BabyPbk() {
    signal input {minvalue,maxvalue} in;
    Point output {babyedwards} A;


    var r = 2736030358979909402780800718157159386076813972158567259200215660948447373041;
    assert(in.minvalue > 0 && in.maxvalue < r);
    var BASE8[2] = [
        5299619240641551281634865583518297030282874472190772894086521144482721001553,
        16950150798460657717958625567821834550301663161624707787222815936182638968203
    ];

    component pvkBits = Num2Bits(253);
    pvkBits.in <== in;

    component mulFix = EscalarMulFix(253, BASE8);

    var i;
    for (i=0; i<253; i++) {
        mulFix.e[i] <== pvkBits.out[i];
    }

    A <== mulFix.out;
}