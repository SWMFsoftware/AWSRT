
filename='./RESULTS/IH/z=0*.outs'
npict=1
read_data
func='{br}*r^2<0.2>(-0.2) bx;by ur ux;uy'
savemovie='mp4'
videofile='z=0_IH'
!x.range=[-220,220]
!y.range=[-220,220]
animate_data

filename='./RESULTS/SC/z=0*.outs'
npict=1
read_data
func='{br}*r^2<0.2>(-0.2) bx;by ur ux;uy'
savemovie='mp4'
videofile='z=0_SC'
!x.range=[-5,5]
!y.range=[-5,5]
animate_data

exit
