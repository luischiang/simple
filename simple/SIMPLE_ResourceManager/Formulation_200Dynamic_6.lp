Minimize
 Cost:   LoadFunction 
Subject To
Coverage.1: d_1_0 + d_1_1 + d_1_2 + d_1_3  >= 6
ProcLoad.M3: Load_M3  -  d_1_3 -  d_1_2 = 0
ProcLoad.M1: Load_M1  -  d_1_0 -  d_1_1 = 0
ProcLoad.M2: Load_M2  -  d_1_0 -  d_1_3 = 0
ProcLoad.M4: Load_M4  -  d_1_1 -  d_1_2 = 0
MaxProcLoadBound.M3: Load_M3 - LoadFunction <= 0
MaxProcLoadBound.M1: Load_M1 - LoadFunction <= 0
MaxProcLoadBound.M2: Load_M2 - LoadFunction <= 0
MaxProcLoadBound.M4: Load_M4 - LoadFunction <= 0
RuleLoad.S1:  1 d_1_0 + 1 d_1_1 + 1 d_1_3 + 1 d_1_2 <= 200
RuleLoad.S2:  3 d_1_0 + 2 d_1_1 + 2 d_1_3 <= 200
RuleLoad.S5:  1 d_1_0 + 1 d_1_1 + 1 d_1_3 + 1 d_1_2 <= 200
RuleLoad.S4:  1 d_1_0 + 3 d_1_1 + 2 d_1_3 + 3 d_1_2 <= 200
RuleLoad.S3:  1 d_1_1 + 2 d_1_3 + 3 d_1_2 <= 200
Binaries
d_1_0
d_1_1
d_1_2
d_1_3
End
