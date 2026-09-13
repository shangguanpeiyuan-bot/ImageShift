# Prepared by tool/prepare_media_bundle.ps1, which verifies archive and file hashes.
set(IMAGESHIFT_MEDIA_RUNTIME "${CMAKE_CURRENT_SOURCE_DIR}/../artifacts/media-upgrade/runtime/ffmpeg")
if(EXISTS "${IMAGESHIFT_MEDIA_RUNTIME}/ffmpeg.exe")
  install(FILES
    "${IMAGESHIFT_MEDIA_RUNTIME}/avcodec-63.dll"
    "${IMAGESHIFT_MEDIA_RUNTIME}/avdevice-63.dll"
    "${IMAGESHIFT_MEDIA_RUNTIME}/avfilter-12.dll"
    "${IMAGESHIFT_MEDIA_RUNTIME}/avformat-63.dll"
    "${IMAGESHIFT_MEDIA_RUNTIME}/avutil-61.dll"
    "${IMAGESHIFT_MEDIA_RUNTIME}/ffmpeg.exe"
    "${IMAGESHIFT_MEDIA_RUNTIME}/ffprobe.exe"
    "${IMAGESHIFT_MEDIA_RUNTIME}/swresample-7.dll"
    "${IMAGESHIFT_MEDIA_RUNTIME}/swscale-10.dll"
    "${IMAGESHIFT_MEDIA_RUNTIME}/LICENSE.txt"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/media/ffmpeg" COMPONENT Runtime)
else()
  message(STATUS "FFmpeg bundle absent: audio/video stays unavailable. Run tool/prepare_media_bundle.ps1.")
endif()
