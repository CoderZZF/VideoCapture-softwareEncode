//
//  H264Encoder.m
//  直播
//
//  Created by zhangzhifu on 2017/3/13.
//  Copyright © 2017年 seemygo. All rights reserved.
//

#import "H264Encoder.h"
#import <VideoToolbox/VideoToolbox.h>
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
//#import "avformat.h"
//#import "avcodec.h"

@interface H264Encoder ()
{
    AVFormatContext *pFormatCtx;
    AVFrame *pFrame;
    uint8_t *buffer;
}

@end

@implementation H264Encoder

#pragma mark - 准备工作
- (void)prepareEncodeWithWidth:(int)width height:(int)height {
    // 1. 注册所有的存储格式和编码格式
    av_register_all();
    
    // 2. 创建AVFormatContext
    // 2.1 创建AVFormatContext
    pFormatCtx = avformat_alloc_context();
    
    // 2.2 创建一个输出流
    NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) firstObject] stringByAppendingPathComponent:@"abc.h264"];
    AVOutputFormat *pOutputFmt = av_guess_format(NULL, [filePath UTF8String] , NULL);
    pFormatCtx->oformat = pOutputFmt;
    
    // 2.3 打开输出流
    if (avio_open(&pFormatCtx->pb, [filePath UTF8String], AVIO_FLAG_READ_WRITE) < 0) {
        NSLog(@"文件打开失败");
        return;
    };
    
    // 3. 创建AVStream
    // 3.1 创建一个流
    AVStream *pStream = avformat_new_stream(pFormatCtx, 0);
    
    // 4. 获取AVCodecContext
    if (pStream == NULL) {
        NSLog(@"创建AVStream失败");
        return;
    }
    
    // 3.3 设置time_base(用于之后计算pts/dts)
    // num : 分子
    // den : 分母
    pStream->time_base.num = 1;
    pStream->time_base.den = 90000;
    
    // 4. 获取AVCodeContext : 包含了编码所有的参数
    // 4.1 从AVStream中取出AVCodecContext
    AVCodecContext *pCodecCtx = pStream->codec;
    
    // 4.2 设置编码的数据是音频还是视频
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    
    // 4.3 设置编码标准
    pCodecCtx->codec_id = AV_CODEC_ID_H264;
    
    // 4.4 设置图片的格式
    pCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P;
    
    // 4.5 设置视频宽度和高度
    pCodecCtx->width = width;
    pCodecCtx->height = height;
    
    // 4.6 最大的B帧的个数
    pCodecCtx->max_b_frames = 3;
    
    // 4.7 设置帧率
    pCodecCtx->time_base.num = 1;
    pCodecCtx->time_base.den = 24;
    
    // 4.8 设置gop的大小
    pCodecCtx->gop_size = 30;
    
    // 4.9 设置比特率
    pCodecCtx->bit_rate = 1500000;
    
    // 4.10 设置最大的音频质量&最小的音频质量
    pCodecCtx->qmin = 10;
    pCodecCtx->qmax = 51;
    
    // 5. 查找AVCodec
    // 5.1 查找编码器
    AVCodec *pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    
    // 5.2 判断是否为null
    if (pCodec == NULL) {
        NSLog(@"查找编码器失败");
        return;
    }
    
    // 5.3 打开编码器
    // 如果是h264编码标准,必须设置options
    AVDictionary *options;
    // 设置视频的编码和视频质量的负载平衡
    av_dict_set(&options, "preset", "slow", 0);
    av_dict_set(&options, "tune", "zerolatency", 0);
    if (avcodec_open2(pCodecCtx, pCodec, &options) < 0) {
        NSLog(@"打开编码器失败");
        return;
    };
    
    // 6. 创建AVFrame -> AVPacket
    pFrame = av_frame_alloc();
    avpicture_fill((AVPicture *)pFrame, buffer, AV_PIX_FMT_YUV420P, width, height);
}


- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer {
    
}


- (void)endEncode {
    
}
@end
