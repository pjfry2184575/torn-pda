import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { sendEnergyNotification, sendNerveNotification, 
  logTravelArrival, sendHospitalNotification, 
  sendDrugsNotification, sendRacingNotification, 
  sendMessagesNotification, sendEventsNotification, 
  sendForeignRestockNotification } from "./notification";
import { getUsersStat } from "./torn_api";

const runtimeOpts = {
  timeoutSeconds: 120,
  memory: "512MB" as "512MB",
}

export const alertsGroup = {

  checkAllUser: functions.region('us-east4')
  .runWith(runtimeOpts)
  .pubsub
  .schedule("*/3 * * * *")
  .onRun(async () => {

    /////////////////////////////////
    // CHANGE TO FALSE BEFORE DEPLOY!
    const debugManuito = false;
    /////////////////////////////////

    const promisesGlobal: Promise<any>[] = [];

    const millisAtStart = Date.now();

    // Get existing stocks from Realtime DB
    const firebaseAdmin = require("firebase-admin");
    const db = firebaseAdmin.database();
    const stocksDB = db.ref("stocks/restocks");
    const foreignStocks = {};
    await stocksDB.once("value", function(snapshot) {
      snapshot.forEach(function(childSnapshot) {
        foreignStocks[childSnapshot.val().codeName] = childSnapshot.val();
      });
    });

    async function checkManuito() {
      const promises: Promise<any>[] = [];

      // Get the list of subscribers
      const response = await admin
        .firestore()
        .collection("players")
        .where("active", "==", true)
        .where("alertsEnabled", "==", true)
        .where("name", "==", "Manuito")
        .get();

      const subscribers = response.docs.map((d) => d.data());
      console.log("Manuito check: " + subscribers.length);
      for(const key of Array.from(subscribers.keys()) ) {
        promises.push(sendNotificationForProfile(subscribers[key], foreignStocks));
      }

      return Promise.all(promises).then(function(value) {
        const millisAfterFinish = Date.now();
        const difference = (millisAfterFinish - millisAtStart) / 1000;
        console.log(`Manuito finished: ${difference} seconds`);
        return value;
      });
    }
    
    async function checkIOS() {
      const promises: Promise<any>[] = [];

      // Get the list of subscribers
      const response = await admin
        .firestore()
        .collection("players")
        .where("active", "==", true)
        .where("alertsEnabled", "==", true)
        .where("platform", "==", "ios")
        .get();

      const subscribers = response.docs.map((d) => d.data());
      console.log("iOS check: " + subscribers.length);
      for(const key of Array.from(subscribers.keys()) ) {
        promises.push(sendNotificationForProfile(subscribers[key], foreignStocks));
      }

      return Promise.all(promises).then(function(value) {
        const millisAfterFinish = Date.now();
        const difference = (millisAfterFinish - millisAtStart) / 1000;
        console.log(`iOS finished: ${difference} seconds`);
        return value;
      });
    }

    async function checkAndroidLow() {
      const promises: Promise<any>[] = [];
  
      // Get the list of subscribers
      const response = await admin
        .firestore()
        .collection("players")
        .where("active", "==", true)
        .where("alertsEnabled", "==", true)
        .where("platform", "==", "android")
        .where("level", "<", 30)
        .get();
      
      const subscribers = response.docs.map((d) => d.data());
      console.log("Android check LOW: " + subscribers.length);
      for(const key of Array.from(subscribers.keys()) ) {
        promises.push(sendNotificationForProfile(subscribers[key], foreignStocks));
      }
  
      return Promise.all(promises).then(function(value) {
        const millisAfterFinish = Date.now();
        const difference = (millisAfterFinish - millisAtStart) / 1000;
        console.log(`Android LOW finished: ${difference} seconds`);
        return value;
      });
    }

    async function checkAndroidHigh() {
      const promises: Promise<any>[] = [];
  
      // Get the list of subscribers
      const response = await admin
        .firestore()
        .collection("players")
        .where("active", "==", true)
        .where("alertsEnabled", "==", true)
        .where("platform", "==", "android")
        .where("level", ">=", 30)
        .get();
        
      const subscribers = response.docs.map((d) => d.data());
      console.log("Android check HIGH: " + subscribers.length);
      for(const key of Array.from(subscribers.keys()) ) {
        promises.push(sendNotificationForProfile(subscribers[key], foreignStocks));
      }
  
      return Promise.all(promises).then(function(value) {
        const millisAfterFinish = Date.now();
        const difference = (millisAfterFinish - millisAtStart) / 1000;
        console.log(`Android HIGH finished: ${difference} seconds`);
        return value;
      });
    }

    // FOR TESTING
    if (debugManuito) {
      promisesGlobal.push(checkManuito());
    } else {
      promisesGlobal.push(checkIOS());
      promisesGlobal.push(checkAndroidLow());
      promisesGlobal.push(checkAndroidHigh());
    }

    await Promise.all(promisesGlobal);

  }),

};

async function sendNotificationForProfile(subscriber: any, stocks: any): Promise<any> {
  const promises: Promise<any>[] = [];

  try {

    const userStats = await getUsersStat(subscriber.apiKey);

    if (!userStats.error) {
      if (subscriber.energyNotification)
        promises.push(sendEnergyNotification(userStats, subscriber));
      if (subscriber.nerveNotification)
        promises.push(sendNerveNotification(userStats, subscriber));
      if (subscriber.travelNotification)
        promises.push(logTravelArrival(userStats, subscriber));
      if (subscriber.hospitalNotification)
        promises.push(sendHospitalNotification(userStats, subscriber));
      if (subscriber.drugsNotification)
        promises.push(sendDrugsNotification(userStats, subscriber));
      if (subscriber.racingNotification)
        promises.push(sendRacingNotification(userStats, subscriber));
      if (subscriber.messagesNotification)
        promises.push(sendMessagesNotification(userStats, subscriber));
      if (subscriber.eventsNotification)
        promises.push(sendEventsNotification(userStats, subscriber));
      if (subscriber.foreignRestockNotification)
        promises.push(sendForeignRestockNotification(userStats, stocks, subscriber));

      await Promise.all(promises);
    }
  } catch (e) {
    functions.logger.warn(`ERROR ALERTS \n${subscriber.uid} \n${e}`);

    // If users uninstall without removing API Key, this error will trigger
    // because the token is not known. In this case, stale the user
    if (e.toString().includes("Requested entity was not found")) {
      await admin
        .firestore()
        .collection("players")
        .doc(subscriber.uid)
        .update({
          active: false,
        });
      functions.logger.warn(`Staled: ${subscriber.name}[${subscriber.playerId}] with UID ${subscriber.uid}`);
    }
  }

}

// Helper function to calculate estimated billing amount, commented because cloud functions wouldnt allow to deploy
// function getEstimatedPrice(estimatedWeeklyActiveUsers: number) {
//   const numberOfExecutionsPerDay = 1440; //  Minutes in a day
//   const totalDocumentReadsPerDay =
//     estimatedWeeklyActiveUsers * numberOfExecutionsPerDay;

//   const paidDocumentReadsPerDay = totalDocumentReadsPerDay - 50000; // 50k per day is free
//   const pricePer100KRead = 0.06;
//   const paidDocumentKReadsPerDay = paidDocumentReadsPerDay / 100000;
//   const priceOfNotificationSender = paidDocumentKReadsPerDay * pricePer100KRead;
//   const estimatedBillForCloudFunction = 5; // 5$ per month as of my estimation, can be optimized;
//   return {
//     estimatedWeeklyActiveUsers,
//     estimatedDailyBill: priceOfNotificationSender,
//     estimatedMonthlyBill: priceOfNotificationSender * 30,
//     estimatedBillForCloudFunction,
//   };
// }
