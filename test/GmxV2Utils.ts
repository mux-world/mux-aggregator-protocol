import { ethers, network } from "hardhat"
import {
  EventLog1Event,
  EventLog2Event,
  EventLogEvent,
  EventLogEventObject,
} from "../typechain/contracts/aggregators/gmxV2/interfaces/IEvent"
import { IEvent__factory } from "../typechain"
import { Log } from "@ethersproject/abstract-provider"

export function hashData(dataTypes: any, dataValues: any) {
  const bytes = ethers.utils.defaultAbiCoder.encode(dataTypes, dataValues)
  const hash = ethers.utils.keccak256(ethers.utils.arrayify(bytes))

  return hash
}

export function hashString(string: any) {
  return hashData(["string"], [string])
}

export const getBaseRealtimeData = (block: any) => {
  return {
    feedId: hashString("feedId"),
    observationsTimestamp: block.timestamp,
    median: 0,
    bid: 0,
    ask: 0,
    blocknumberUpperBound: block.number,
    upperBlockhash: "0x0000000000000000000000000000000000000000000000000000000000000000",
    blocknumberLowerBound: block.number,
    currentBlockTimestamp: block.timestamp,
  }
}

export function encodeRealtimeData(data: any) {
  const {
    feedId,
    observationsTimestamp,
    median,
    bid,
    ask,
    blocknumberUpperBound,
    upperBlockhash,
    blocknumberLowerBound,
    currentBlockTimestamp,
  } = data
  return ethers.utils.defaultAbiCoder.encode(
    ["bytes32", "uint32", "int192", "int192", "int192", "uint64", "bytes32", "uint64", "uint64"],
    [
      feedId,
      observationsTimestamp,
      median,
      bid,
      ask,
      blocknumberUpperBound,
      upperBlockhash,
      blocknumberLowerBound,
      currentBlockTimestamp,
    ]
  )
}

export function parseEventLog(log: Log) {
  const iface = IEvent__factory.createInterface()
  const EVENT_LOG_TOPIC = iface.getEventTopic("EventLog")
  const EVENT_LOG1_TOPIC = iface.getEventTopic("EventLog1")
  const EVENT_LOG2_TOPIC = iface.getEventTopic("EventLog2")

  if (log.topics[0] === EVENT_LOG_TOPIC) {
    const decoded = iface.decodeEventLog("EventLog", log.data) as unknown as EventLogEventObject
    const params = parseEventLogData(decoded.eventData)
    return {
      eventName: decoded.eventName,
      params,
    }
  } else if (log.topics[0] === EVENT_LOG1_TOPIC) {
    const decoded = iface.decodeEventLog("EventLog1", log.data) as unknown as EventLogEventObject
    const params = parseEventLogData(decoded.eventData)
    return {
      eventName: decoded.eventName,
      params,
    }
  } else if (log.topics[0] === EVENT_LOG2_TOPIC) {
    const decoded = iface.decodeEventLog("EventLog2", log.data) as unknown as EventLogEventObject
    const params = parseEventLogData(decoded.eventData)
    return {
      eventName: decoded.eventName,
      params,
    }
  }
}

export function parseEventLogData(eventData: any): { [k: string]: string } {
  const ret: { [k: string]: string } = {}
  for (const typeKey of [
    "addressItems",
    "uintItems",
    "intItems",
    "boolItems",
    "bytes32Items",
    "bytesItems",
    "stringItems",
  ]) {
    for (const listKey of ["items", "arrayItems"]) {
      for (const item of eventData[typeKey][listKey]) {
        if (typeof ret[item.key] !== "undefined") {
          throw new Error(`duplicate key ${item.key} in ${eventData}`)
        }
        ret[item.key] = item.value.toString()
      }
    }
  }
  return ret
}
