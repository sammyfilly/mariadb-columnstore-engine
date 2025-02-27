/* Copyright (C) 2014 InfiniDB, Inc.
   Copyright (C) 2016 MariaDB Corporation

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; version 2 of
   the License.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02110-1301, USA. */

#include <string>
//#define NDEBUG
#include <cassert>
#include <map>
#include <set>
#include <atomic>
using namespace std;

#include <boost/thread.hpp>
using namespace boost;

#define OAMCACHE_DLLEXPORT
#include "oamcache.h"
#undef OAMCACHE_DLLEXPORT
#include "liboamcpp.h"
#include "exceptclasses.h"
#include "configcpp.h"
#include "installdir.h"
#include "mcsconfig.h"

namespace oam
{


struct CacheReloaded
{
  CacheReloaded()
  {
    oamcache.checkReload();
  }
  OamCache oamcache;
};


OamCache* OamCache::makeOamCache()
{
  static CacheReloaded cache;
  return &cache.oamcache;
}

void OamCache::checkReload()
{
  Oam oam;
  config::Config* config = config::Config::makeConfig();
  int temp;

  if (config->getCurrentMTime() == mtime)
    return;

  dbroots.clear();
  oam.getSystemDbrootConfig(dbroots);

  string txt = config->getConfig("SystemConfig", "DBRootCount");
  mtime = config->getLastMTime();  // get 'last' after the first access; quicker than 'current'
  idbassert(txt != "");
  numDBRoots = config->fromText(txt);

  dbRootPMMap.reset(new map<int, int>());

  // cerr << "reloading oamcache\n";
  for (uint32_t i = 0; i < dbroots.size(); i++)
  {
    oam.getDbrootPmConfig(dbroots[i], temp);
    // cout << "  dbroot " << dbroots[i] << " -> PM " << temp << endl;
    (*dbRootPMMap)[dbroots[i]] = temp;
  }

  ModuleTypeConfig moduletypeconfig;
  std::set<int> uniquePids;
  oam.getSystemConfig("pm", moduletypeconfig);
  int moduleID = 0;

  for (unsigned i = 0; i < moduletypeconfig.ModuleCount; i++)
  {
    moduleID = atoi((moduletypeconfig.ModuleNetworkList[i])
                        .DeviceName.substr(MAX_MODULE_TYPE_SIZE, MAX_MODULE_ID_SIZE)
                        .c_str());
    uniquePids.insert(moduleID);
  }

  std::set<int>::const_iterator it = uniquePids.begin();
  moduleIds.clear();
  uint32_t i = 0;
  map<int, int> pmToConnectionMap;

  // Restore for Windows when we support multiple PMs
  while (it != uniquePids.end())
  {
    pmToConnectionMap[*it] = i++;
    moduleIds.push_back(*it);
    it++;
  }

  dbRootConnectionMap.reset(new map<int, int>());

  for (i = 0; i < dbroots.size(); i++)
  {
    map<int, int>::iterator pmIter = pmToConnectionMap.find((*dbRootPMMap)[dbroots[i]]);

    if (pmIter != pmToConnectionMap.end())
    {
      (*dbRootConnectionMap)[dbroots[i]] = (*pmIter).second;
    }
  }

  pmDbrootsMap.reset(new OamCache::PMDbrootsMap_t::element_type());
  systemStorageInfo_t t;
  t = oam.getStorageConfig();
  DeviceDBRootList moduledbrootlist = boost::get<2>(t);
  DeviceDBRootList::iterator pt = moduledbrootlist.begin();

  for (; pt != moduledbrootlist.end(); pt++)
  {
    moduleID = (*pt).DeviceID;
    DBRootConfigList::iterator pt1 = (*pt).dbrootConfigList.begin();

    for (; pt1 != (*pt).dbrootConfigList.end(); pt1++)
    {
      (*pmDbrootsMap)[moduleID].push_back(*pt1);
    }
  }

  oamModuleInfo_t tm;
  tm = oam.getModuleInfo();
  OAMParentModuleName = boost::get<3>(tm);
  systemName = config->getConfig("SystemConfig", "SystemName");
}

OamCache::dbRootPMMap_t OamCache::getDBRootToPMMap()
{
  return dbRootPMMap;
}

OamCache::dbRootPMMap_t OamCache::getDBRootToConnectionMap()
{
  return dbRootConnectionMap;
}

OamCache::PMDbrootsMap_t OamCache::getPMToDbrootsMap()
{
  return pmDbrootsMap;
}

uint32_t OamCache::getDBRootCount()
{
  return numDBRoots;
}

DBRootConfigList& OamCache::getDBRootNums()
{
  return dbroots;
}

std::vector<int>& OamCache::getModuleIds()
{
  return moduleIds;
}

std::string OamCache::getOAMParentModuleName()
{
  return OAMParentModuleName;
}

int OamCache::getLocalPMId()
{
  // This comes from the file /var/lib/columnstore/local/module, not from the xml.
  // Thus, it's not refreshed during checkReload().
  if (mLocalPMId > 0)
  {
    return mLocalPMId;
  }

  string localModule;
  string moduleType;
  string fileName = "/var/lib/columnstore/local/module";
  ifstream moduleFile(fileName.c_str());
  char line[400];

  while (moduleFile.getline(line, 400))
  {
    localModule = line;
    break;
  }

  moduleFile.close();

  if (localModule.empty())
  {
    mLocalPMId = 0;
    return mLocalPMId;
  }

  moduleType = localModule.substr(0, MAX_MODULE_TYPE_SIZE);
  mLocalPMId = atoi(localModule.substr(MAX_MODULE_TYPE_SIZE, MAX_MODULE_ID_SIZE).c_str());

  if (moduleType != "pm")
  {
    mLocalPMId = 0;
  }

  return mLocalPMId;
}

string OamCache::getSystemName()
{
  return systemName;
}

string OamCache::getModuleName()
{
  if (!moduleName.empty())
    return moduleName;

  string fileName = "/var/lib/columnstore/local/module";
  ifstream moduleFile(fileName.c_str());
  getline(moduleFile, moduleName);
  moduleFile.close();

  return moduleName;
}

} /* namespace oam */
