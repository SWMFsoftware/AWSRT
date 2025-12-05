filename='./RESULTS/SC/x=0*n0*000*.outs'
npict=1
firstpict=61
read_data
func='{br}*r^2<0.2>(-0.2) by;bz ur uy;uz'
savemovie='mp4'
videorate=3
videofile='x=0_range'
!x.range=[-5,5]
!y.range=[-5,5]
animate_data
animate_data


filename='./RESULTS/SC/y=0*n0*000*.outs'
npict=1
firstpict=61
read_data
func='{br}*r^2<0.2>(-0.2) bx;bz ur ux;uz'
savemovie='mp4'
videorate=3
videofile='y=0_range'
!x.range=[-5,5]
!y.range=[-5,5]
animate_data

filename='./RESULTS/SC/z=0*n0*000*.outs'
npict=1
firstpict=61
read_data
func='{br}*r^2<0.2>(-0.2) bx;by ur ux;uy'
savemovie='mp4'
videorate=3
videofile='z=0_range'
!x.range=[-5,5]
!y.range=[-5,5]
animate_data


exit
