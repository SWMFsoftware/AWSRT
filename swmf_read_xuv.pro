; reading SWMF output files for EUV images (aia)
pro swmf_read_xuv, filename, $
  if_eps = if_eps, $
  if_compare = if_compare, $
  data_dir = data_dir
  compile_opt idl2

  default, hl, 9
  default, npix, 512
  default, if_eps, 1
  default, if_combined_euv, 0
  default, if_compare, 0

  if not keyword_set(filename) then begin
    print, 'Please provide a filename.'
    return
  endif

  if if_compare then if not keyword_set(data_dir) then begin
    print, 'Please provide the directory for data.'
    return
  endif
  openr, lun, filename, /get_lun
  
  lenstr = 79
  headline = ''
  for i=1, lenstr do headline = headline + ' '
  it      = 1L
  ndim    = 1L
  neqpar  = 0L
  eqpar   = 0.0
  nw      = 1L
  varname = ''
  for i=1, lenstr do varname = varname + ' '
  time=double(1)
  readf, lun, headline
  readf, lun, it, time, ndim, neqpar, nw
  nx = lonarr(ndim)
  readf, lun, nx
  npix = nx[0]
  if neqpar gt 0 then begin
     eqpar = dblarr(neqpar)
     readf, lun, eqpar
  endif
  readf, lun, varname

  data = fltarr(12)
  aia_131 = fltarr(npix, npix)
  aia_171 = fltarr(npix, npix)
  aia_193 = fltarr(npix, npix)
  aia_211 = fltarr(npix, npix)
  aia_335 = fltarr(npix, npix)
  xrt_tipoly = fltarr(npix, npix)

  for i = 0, npix - 1 do begin
    for j = 0, npix - 1 do begin
      readf, lun, data
      aia_131[i, j] = data[3]
      aia_171[i, j] = data[4]
      aia_193[i, j] = data[5]
      aia_211[i, j] = data[6]
      aia_335[i, j] = data[8]
      xrt_tipoly[i, j] = data[11]
    endfor
  endfor

  free_lun, lun
  
  if if_eps then begin
    set_plot, 'ps'
    device, filename = file_dirname(filename) + '/' + $
            file_basename(filename, '_000.out') + '.eps', $
            xsize = 45, ysize = 30, /color, /encapsul, bits = 8
    !p.font = 2

    posi_list = get_posi([0, 0.05, 0.3, 0.45, 0.332, 0.48], 3, 2)

    line_list = ['131', '171', '193', '211', '335', '3']
    titles = ['AIA 131', 'AIA 171', 'AIA 193', 'AIA 211', $
              'AIA 335', 'XRT Ti-Poly']
    max_list = [2.5, 3.5, 3, 3, 2, 1.5]
    min_list = [0., 0., 0.5, 0.0, -0.5, -1.]

    for i = 0, 5 do begin
       ; assign img1 to be aia_131/171/193/211/335/xrt_tipoly
       if i lt 5 then a = execute('img1=aia_' + line_list[i]) $
       else img1 = xrt_tipoly
       ; choose a color table accordingly
       if i lt 5 then aia_lct, wave = line_list[i], /load else loadct, 3
       ; plot six images into a single eps figure
       PLOT_IMAGE, posi = posi_list[i mod 3, i / 3, *], max = max_list[i], $
                   min = min_list[i], alog10(img1), xst = 5, yst = 5, $
                   /noerase, title = titles[i], color = 0, charsize = 1.0
    endfor

    device, /close
    set_plot, 'x'
    !p.font = -1
  endif

  if if_compare then begin
    line_list = ['131', '171', '193', '211']
    max_list = [3., 4., 4., 4.]
    min_list = max_list - 3.5
    obs_all = fltarr(npix, npix, 3, n_elements(line_list))

    files_data = file_search(data_dir, 'AIA*jpg')
    for i = 0, n_elements(files_data) - 1 do begin
       for j = 0, n_elements(line_list) - 1 do begin
          if line_list[j] eq strmid(file_basename(files_data[i]), 4, 3) then $
             begin
             read_jpeg, files_data[i], img_obs, TRUE=3
             obs_all[*, *, *, j] = rebin(img_obs, npix, npix, 3)
          endif
       end
    end

    set_plot, 'ps'
    device, filename = file_dirname(filename) +'/' + $
            file_basename(filename, '_000.out') + '_compare.eps', $
            xsize = 36, ysize = 20, /color, /encapsul, bits = 8
    !p.font = 2

    posi_list = get_posi([0.04, 0.04, 0.22, 0.396, 0.24, 0.45], 4, 2)

    for i = 0, 3 do begin
       aia_lct, wave = line_list[i], /load
       a = execute('img1=aia_' + line_list[i])
       PLOT_IMAGE, posi = posi_list[i, 0, *], $
                   max = max_list[i], min = min_list[i], alog10(img1), $
                   xst = 5, yst = 5, /noerase, title = $
                   'AIA ' + line_list[i] + ' Model', color = 0, charsize = 1.0

       loadct,0
       PLOT_IMAGE, posi = posi_list[i, 1, *], obs_all[*, *, *, i], type='jpeg',$
                   xst = 5, yst = 5, /noerase, $
                   title = 'AIA ' + line_list[i] + ' Observation', $
                   color = 0s, charsize = 1.0
    end

    device, /close
    set_plot, 'x'
    !p.font = -1
  endif
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
function get_posi,a,ix,iy

ax=a[0]
ay=a[1]
lx=a[2]
ly=a[3]
dx=a[4]
dy=a[5]

posi_list=fltarr(ix,iy,4)
posi_list[0,0,*]=[ax,1-ay-ly,ax+lx,1-ay]
if ix gt 1 then for i=1,ix-1 do posi_list[i,0,*]=$
   posi_list[i-1,0,*]+[1,0,1,0]*dx
if iy gt 1 then for i=0,ix-1 do for j=1,iy-1 do posi_list[i,j,*]=$
   posi_list[i,j-1,*]-[0,1,0,1]*dy

return,posi_list

end

