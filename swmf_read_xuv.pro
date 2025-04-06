; reading SWMF output files for EUV images (aia)
pro swmf_read_xuv, filename, $
  if_eps = if_eps, $
  if_compare = if_compare, $
  data_dir = data_dir, $
  if_combined_euv = if_combined_euv
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

;  head = string(1)
;  for i = 0, hl - 1 do readf, lun, head
; Version for ASCII .out files:
  
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
    device, filename = file_dirname(filename) + '/' + file_basename(filename, '.out') + '.eps', $
            xsize = 45, ysize = 30, /color, /encapsul, bits = 8
    !p.font = 2

    posi_list = get_posi([0, 0, 0.334, 0.5, 0.332, 0.5], 3, 2)

    line_list = ['131', '171', '193', '211', '335', '3']
    max_list = [2.5, 3.5, 3, 3, 2, 1.5]
    min_list = [0., 0., 0.5, 0.0, -0.5, -1.]

    for i = 0, 5 do begin
; assign img1 to be aia_131 / aia_171 / aia_193 / aia_211 / aia_335 / xrt_tipoly
      if i lt 5 then a = execute('img1=aia_' + line_list[i]) else img1 = xrt_tipoly
; choose a color table accordingly       
      if i lt 5 then aia_lct, wave = line_list[i], /load else loadct, 3
; plot six images into a single eps figure
      PLOT_IMAGE, posi = posi_list[i mod 3, i / 3, *], max = max_list[i], min = min_list[i], $
                  alog10(img1), xst = 5, yst = 5, /noerase
    endfor

    device, /close
    set_plot, 'x'
    !p.font = -1
  endif

  if if_combined_euv then begin
    line_list = ['211', '193', '171']
    max_list = [2.5, 3.25, 4.25]
    min_list = [0., 0.25, 1.25]
    rgb = fltarr(3, npix * 2, npix * 2)
    for i = 0, 2 do begin
      a = execute('img1=aia_' + line_list[i])
      rgb[i, *, *] = bytscl(alog10(rebin(img1, npix * 2, npix * 2)), max = max_list[i], min = min_list[i])
    endfor

    write_png, file_dirname(filename) + '/combined_euv.png', rgb

    if if_compare then begin
      files_data = file_search(data_dir, 'AIA*fits')
      for i = 0, n_elements(files_data) - 1 do begin
        for j = 0, n_elements(line_list) - 1 do begin
          if line_list[j] eq strmid(file_basename(files_data[i]), 20, 3) then begin
            read_sdo, files_data[i], index, img_obs
            sz_obs = size(img_obs)
            if not keyword_set(obs_all) then begin
               obs_all = fltarr(sz_obs[1], sz_obs[2], n_elements(line_list))
            endif
            obs_all[*, *, j] = img_obs
          endif
        end
      end

      for i = 0, 2 do rgb[i, *, *] = bytscl(alog10(obs_all[*, *, i]), max = max_list[i], min = min_list[i])
    endif
    write_png, file_dirname(filename) + '/combined_euv_reals.png', rgb
    if keyword_set(obs_all) then undefine, obs_all
  endif

  if if_compare then begin
    line_list = ['131', '171', '193', '211']
    max_list = [3., 4., 4., 4.]
    min_list = max_list - 3.5

    files_data = file_search(data_dir, 'AIA*fits')
    for i = 0, n_elements(files_data) - 1 do begin
      for j = 0, n_elements(line_list) - 1 do begin
        if line_list[j] eq strmid(file_basename(files_data[i]), 20, 3) then begin
          read_sdo, files_data[i], index, img_obs
          sz_obs = size(img_obs)
          if not keyword_set(obs_all) then begin
            obs_all = fltarr(sz_obs[1], sz_obs[2], n_elements(line_list))
          endif
          obs_all[*, *, j] = img_obs
        endif
      end
    end

    set_plot, 'ps'
    device, filename = file_dirname(filename) + '/aia_compare.eps', xsize = 36, ysize = 20, /color, /encapsul, bits = 8
    !p.font = 2

    posi_list = get_posi([0.04, 0.04, 0.22, 0.396, 0.24, 0.45], 4, 2)

    for i = 0, 3 do begin
      aia_lct, wave = line_list[i], /load
      a = execute('img1=aia_' + line_list[i])
      img1 = interpolate(img1, 256 + (findgen(512) + 0.5 - 256) * 1.25 / 1.98, 256 + (findgen(512) + 0.5 - 256) * 1.25 / 1.98, /grid)
      img2 = rebin(obs_all[*, *, i], sz_obs[1] / 2, sz_obs[2] / 2)
      PLOT_IMAGE, posi = posi_list[i, 0, *], max = max_list[i], min = min_list[i], alog10(img1), $
        xst = 5, yst = 5, /noerase, title = 'AIA ' + line_list[i] + ' Model', color = 0, charsize = 1.0
      a = execute('xyouts,20,20,"("+string(' + strtrim(string(97 + i), 2) + 'B)+")",color=255,charsize=1.2')

      if i eq 1 then begin
        arrow, 20, 400, 40, 350, /data, /normalized, hsize = 250, color = 255, thick = 6, /solid
        arrow, 490, 350, 470, 300, /data, /normalized, hsize = 250, color = 255, thick = 6, /solid
        xyouts, 5, 410, 'AR1', color = 255, charsize = 0.8, charthick = 2.
        xyouts, 480, 360, 'CL', color = 255, charsize = 0.8, charthick = 2.
      endif
      PLOT_IMAGE, posi = posi_list[i, 1, *], max = max_list[i], min = min_list[i], alog10(img2), $
        xst = 5, yst = 5, /noerase, title = 'AIA ' + line_list[i] + ' Observation', color = 0s, charsize = 1.0
      a = execute('xyouts,20,20,"("+string(' + strtrim(string(97 + i + 4), 2) + 'B)+")",color=255,charsize=1.2')
      if i eq 1 then begin
        arrow, 20, 400, 40, 350, /data, /normalized, hsize = 250, color = 255, thick = 6, /solid
        arrow, 490, 350, 470, 300, /data, /normalized, hsize = 250, color = 255, thick = 6, /solid
        xyouts, 5, 410, 'AR1', color = 255, charsize = 0.8, charthick = 2.
        xyouts, 480, 360, 'CL', color = 255, charsize = 0.8, charthick = 2.
      endif
      COLORBAR, posi = posi_list[i, 1, *] - [0, 0.13, 0, 1.09] * 0.396, $
        range = [min_list[i], max_list[i]], title = 'log DN/s', charsize = 1., color = 0, $
        div = 4, format = '(f4.1)', /bottom
    endfor

    device, /close
    set_plot, 'x'
    !p.font = -1
  endif
end
