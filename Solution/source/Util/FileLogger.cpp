/*
* Menyoo PC - Grand Theft Auto V single-player trainer mod
* Copyright (C) 2019  MAFINS
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*/
#include "FileLogger.h"

#include "..\macros.h"

#include <fstream>
#include <iomanip>
#include <time.h>
#include <map>
#include <set>
#include "../Natives/natives.h"
#include "../Menu/Menu.h"
#include "../Menu/MenuConfig.h"

namespace ige
{
	FileLogger menyooLogObject("menyooLog.txt");
	std::ofstream& myLog = menyooLogObject.myFile;

    // 添加一个集合来追踪已记录的错误
    static std::set<std::string> logged_errors;

    struct ErrorCount {
        int count;
        time_t first_occurrence; 
    };
    static std::map<std::string, ErrorCount> error_counts;

	FileLogger::FileLogger(std::string fname)
	{
		MenuConfig::ConfigInit();
		myFile.open(fname.c_str());

		if (myFile.is_open())
		{
			time_t now = time(0);
			tm t;
			localtime_s(&t, &now);

			myFile << "Menyoo " << MENYOO_CURRENT_VER_ << std::endl;
			//myFile << "Player Name: " << PLAYER::GET_PLAYER_NAME(-1) << std::endl;
			myFile << "Log file created " << std::setfill('0') << std::setw(2) << t.tm_mday << "/" << std::setfill('0') << std::setw(2) << (t.tm_mon + 1) << "/" << t.tm_year + 1900 << std::endl;
			myFile << "Logging level " << std::to_string(g_loglevel) << " active. Edit loglevel in menyooconfig.ini to change." << std::endl << std::endl;
		}

	}

	FileLogger::~FileLogger()
	{
		if (myFile.is_open())
		{
			myFile << std::endl << std::endl;

			myFile.close();
		}

	}

    // 翻译表结构
    struct TranslationEntry {
        std::string original;
        std::string translated;
        bool hasTranslation;
    };
    
    // 翻译表管理
    static std::map<std::string, TranslationEntry> translation_table;
    
    // 用于控制日志输出频率
    struct LogControl {
        int threshold;      // 输出阈值
        int interval;       // 输出间隔
        time_t cooldown;    // 冷却时间(秒)
    };
    static LogControl log_control = {100, 1000, 3600}; // 默认值
    
    void addlog(LogType logType, std::string message, std::string filename, int loglevel) 
    {
        // 对翻译错误的特殊处理
        if(message.find("Translate string out of range:") == 0) {
            std::string key = message.substr(27); // 提取需要翻译的文本
            
            auto& entry = translation_table[key];
            if(!entry.hasTranslation) {
                entry.original = key;
                entry.translated = key; // 使用原文作为默认翻译
                entry.hasTranslation = true;
                
                // 只在首次遇到未翻译文本时记录
                ige::myLog << LogType::LOG_WARNING 
                          << ": New untranslated string: " << key << std::endl;
            }
            
            // 使用ErrorCount跟踪频率
            auto& count = error_counts[key];
            if(count.count == 0) {
                count.first_occurrence = time(0);
            }
            count.count++;
            
            // 根据频率控制输出
            time_t now = time(0);
            if(count.count == 1 || 
               (count.count % log_control.threshold == 0 && 
                now - count.first_occurrence >= log_control.cooldown)) {
                
                ige::myLog << logType << (loglevel >= 3 ? filename : "")
                          << ": Translation missing for '" << key 
                          << "' (occurred " << count.count 
                          << " times in " 
                          << (now - count.first_occurrence) / 3600.0 
                          << " hours)" << std::endl;
            }
            return;
        }

        // 其他类型日志的处理
        if(static_cast<int>(logType) <= loglevel) {
            ige::myLog << logType << (loglevel >= 3 ? filename : "") 
                      << ": " << message << std::endl;
        }
    }

    // 添加翻译项的辅助函数
    void AddTranslation(const std::string& key, const std::string& value) {
        auto& entry = translation_table[key];
        entry.original = key;
        entry.translated = value;
        entry.hasTranslation = true;
    }

	//overloaded function to define default file and loglevels unless otherwise specified
	void addlog(LogType logType, std::string& message) {
		addlog(logType, message, "", g_loglevel);
	}
}

std::ofstream& operator<<(std::ofstream& stream, ige::LogType logType)
{
	time_t now = time(0);
	tm t;
	localtime_s(&t, &now);

	stream << "[" << std::setfill('0') << std::setw(2) << t.tm_hour << ":" << std::setfill('0') << std::setw(2) << t.tm_min << ":" << std::setfill('0') << std::setw(2) << t.tm_sec << "] ";

	switch (logType)
	{
	case ige::LogType::LOG_INIT: stream << "INIT - "; break;
	case ige::LogType::LOG_ERROR: stream << "ERROR - "; break;
	case ige::LogType::LOG_WARNING: stream << "WARNING - "; break;
	case ige::LogType::LOG_INFO: stream << "INFO - "; break;
	case ige::LogType::LOG_DEBUG: stream << "DEBUG - "; break;
	case ige::LogType::LOG_TRACE: stream << "TRACE - "; break;
	}

	return stream;
}

