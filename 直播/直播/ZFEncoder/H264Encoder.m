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
    AVCodecContext *pCodecCtx;
    AVStream *pStream;
    uint8_t *buffer;
    
    AVFrame *pFrame;
    AVPacket packet;
    
    int frameIndex;
}

@end

@implementation H264Encoder
#pragma mark - 准备工作
- (void)prepareEncodeWithWidth:(int)width height:(int)height {
    frameIndex = 0;
    
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
    pStream = avformat_new_stream(pFormatCtx, 0);
    
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
    pCodecCtx = pStream->codec;
    
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
    AVDictionary *options = NULL;
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
    // pts -> presentation time stamp
    // dts -> decoder time stamp
    
    // 1. CMSampleBufferRef获取CVPixelBufferRef
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // 2. 锁定内存地址CVPixelBufferRef
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess) {
        // 3.从CVPixelBufferRef获取YUV的数据
        // NV12和NV21属于YUV格式，是一种two-plane模式，即Y和UV分为两个Plane，但是UV（CbCr）为交错存储，而不是分为三个plane
        // YUV420
        // 4 : 4 : 4  = 12
        // 4 : 2 : 2
        // 4 : 1 : 1  =  6 --> YUV420  -> UV交错存储    YYYYYYYY  UVUV
        // 3.1.获取Y分量的地址
        UInt8 *bufferPtr = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);
        // 3.2.获取UV分量的地址
        UInt8 *bufferPtr1 = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,1);
        
        // 3.3.根据像素获取图片的真实宽度&高度
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        // 获取Y分量长度
        size_t yBPR = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,0);
        size_t uvBPR = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,1);
        
        // Y : width * height
        // U : width * height / 4
        // V : width * height / 4
        // 1 + 1/4 + 1/4 = 3/2
        // YYYY YYYY YYYY UUUVVV
        UInt8 *yuv420_data = (UInt8 *)malloc(width * height * 3/2);
        
        // 3.4.将NV12数据转成i420数据
        // iOS默认采集的NV12数据 --> YUV420P
        // YUV420 --> two plane -> 4 : 1 : 1
        // NV12 : YYYY YYYY UVUV
        // I420 : YYYY YYYY YYYY UUUVVV
        UInt8 *pU = yuv420_data + width*height;
        UInt8 *pV = pU + width*height/4;
        for(int i =0;i<height;i++)
        {
            memcpy(yuv420_data+i*width,bufferPtr+i*yBPR,width);
        }
        
        for(int j = 0;j<height/2;j++)
        {
            for(int i =0;i<width/2;i++)
            {
                *(pU++) = bufferPtr1[i<<1];
                *(pV++) = bufferPtr1[(i<<1) + 1];
            }
            bufferPtr1+=uvBPR;
        }
        
        
        // 4. 设置AVFrame的属性
        // 4.1 设施YUV数据到AVFrame中
        pFrame->data[0] = yuv420_data;
        pFrame->data[1] = yuv420_data + width * height;
        pFrame->data[2] = yuv420_data + width * height * 5 / 4;
        frameIndex++;
        pFrame->pts = frameIndex;
        
        // 4.2 AVframe设置宽度和高度
        pFrame->width = (int)width;
        pFrame->height = (int)height;
        
        // 4.3 设置格式
        pFrame->format = PIX_FMT_YUV420P;
        
        // 5. 开始进行编码操作
        int got_picture = 0;
        if (avcodec_encode_video2(pCodecCtx, &packet, pFrame, &got_picture) < 0) {
            NSLog(@"编码失败");
            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
            return;
        };
        
        // 6. 将AVPacket写入到文件中
        if (got_picture) {
            // 6.1 设置AVPacket的stream_index
            packet.stream_index = pStream->index;
            
            // 6.2 将packet写入文件
            av_write_frame(pFormatCtx, &packet);
            
            // 6.3 释放资源
            av_free_packet(&packet);
        }
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    }
}


- (void)endEncode {
    flush_encoder(pFormatCtx, pStream->index);
    
    // 1. 将AVFormatContext中没有写入的数据,先全部写入
    av_write_trailer(pFormatCtx);
    
    // 2. 释放资源
    avio_close(pFormatCtx->pb);
    avcodec_close(pCodecCtx);
    free(pFrame);
    free(pFormatCtx);
}

int flush_encoder(AVFormatContext *fmt_ctx,unsigned int stream_index)
{
    int ret;
    int got_frame;
    AVPacket enc_pkt;
    if (!(fmt_ctx->streams[stream_index]->codec->codec->capabilities &
          CODEC_CAP_DELAY))
        return 0;
    
    while (1) {
        enc_pkt.data = NULL;
        enc_pkt.size = 0;
        av_init_packet(&enc_pkt);
        ret = avcodec_encode_video2 (fmt_ctx->streams[stream_index]->codec, &enc_pkt,
                                     NULL, &got_frame);
        av_frame_free(NULL);
        if (ret < 0)
            break;
        if (!got_frame){
            ret=0;
            break;
        }
        ret = av_write_frame(fmt_ctx, &enc_pkt);
        if (ret < 0)
            break;
    }
    return ret;
}

@end
