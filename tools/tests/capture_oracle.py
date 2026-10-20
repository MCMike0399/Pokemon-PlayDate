"""Independent rational/Decimal oracle for Gen V Q12 capture test vectors.

Runtime uses integer long division and binary root search; this deliberately
uses Python Fraction and high-precision Decimal instead. Not runtime code.
"""
from decimal import Decimal, localcontext, ROUND_HALF_UP
from fractions import Fraction

def down(value):return Fraction(value.numerator*4096//value.denominator,4096)
def rounded(value):return Fraction((value.numerator*8192+value.denominator)//(2*value.denominator),4096)
def root(value):
    with localcontext() as ctx:
        ctx.prec=80
        v=(Decimal(value.numerator)/Decimal(value.denominator)).sqrt()*4096
        return Fraction(int(v.to_integral_value(rounding=ROUND_HALF_UP)),4096)
def parameters(rate,hp,maximum,ball,status,count):
    if ball=='masterBall':return {'modifiedRate4096':1044480,'shakeThreshold':65536,'criticalThreshold':0}
    bonus={'pokeBall':Fraction(1),'greatBall':Fraction(3,2),'ultraBall':Fraction(2)}[ball]
    s={'sleep':Fraction(5,2),'freeze':Fraction(5,2),'burn':Fraction(3,2),'poison':Fraction(3,2),'paralyze':Fraction(3,2)}.get(status,Fraction(1))
    a=down(rounded(down(rounded(Fraction((3*maximum-2*hp)*rate)*bonus)/Fraction(3*maximum))*s))
    a=min(Fraction(255),a)
    if a>=255:return {'modifiedRate4096':1044480,'shakeThreshold':65536,'criticalThreshold':0}
    threshold=int(rounded(Fraction(65536)/root(root(rounded(Fraction(255)/a)))))
    p=Fraction(1) if count>150 else (Fraction(1,2) if count>30 else Fraction(0))
    cc=int(rounded(rounded(a*p)/6))
    return {'modifiedRate4096':int(a*4096),'shakeThreshold':threshold,'criticalThreshold':cc}

def attempt(params,seed):
    state=seed;rolls=0
    def random(high):
        nonlocal state,rolls
        limit=(2147483646//(high+1))*(high+1)
        while True:
            state=state*16807%2147483647;rolls+=1
            if state-1<limit:return (state-1)%(high+1)
    if params['modifiedRate4096']>=1044480:return {'caught':True,'critical':False,'checks':0,'displayShakes':3,'rngRolls':0,'state':seed,'criticalRoll':None,'shakeRolls':[]}
    critical_roll=random(255);critical=critical_roll<params['criticalThreshold']
    checks=1 if critical else 3;shake_rolls=[];caught=True
    for check in range(checks):
        roll=random(65535);shake_rolls.append(roll)
        if roll>=params['shakeThreshold']:caught=False;break
    displayed=1 if critical else (3 if caught else [0,1,3][len(shake_rolls)-1])
    return {'caught':caught,'critical':critical,'checks':len(shake_rolls),'displayShakes':displayed,'rngRolls':rolls,'state':state,'criticalRoll':critical_roll,'shakeRolls':shake_rolls}
