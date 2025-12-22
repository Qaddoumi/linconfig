
## darken a video
ffmpeg -i input.mp4 -vf "eq=brightness=-0.1" output.mp4
# adjust gamma instead, which often looks more natural
ffmpeg -i input.mp4 -vf "eq=gamma=0.7" output.mp4

## To reverse a video with FFmpeg (This reverses both video and audio.)
ffmpeg -i input.mp4 -vf reverse -af areverse output.mp4
#If you only want to reverse the video (no audio):If you only want to reverse the video (no audio):
ffmpeg -i input.mp4 -vf reverse output.mp4
#If you only want to reverse the audio (no video):
ffmpeg -i input.mp4 -af areverse output.mp4

## join/concatenate videos
ffmpeg -f concat -safe 0 -i <(for f in *.mp4; do echo "file '$PWD/$f'"; done) -c copy output.mp4
#Concat Demuxer (fastest, no re-encoding)
echo "file 'video1.mp4'" > filelist.txt
echo "file 'video2.mp4'" >> filelist.txt
ffmpeg -f concat -safe 0 -i filelist.txt -c copy output.mp4
#If your videos have different resolutions or formats
ffmpeg -i video1.mp4 -i video2.mp4 -filter_complex "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[outv][outa]" -map "[outv]" -map "[outa]" output.mp4

## remove audio entirely from a video
ffmpeg -i input.mp4 -vcodec copy -an output.mp4