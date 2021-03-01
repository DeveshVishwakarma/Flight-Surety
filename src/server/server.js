import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

let oracle_accounts = [];

const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;
const STATUS_CODES = [STATUS_CODE_UNKNOWN, STATUS_CODE_ON_TIME, STATUS_CODE_LATE_AIRLINE, STATUS_CODE_LATE_WEATHER, STATUS_CODE_LATE_TECHNICAL, STATUS_CODE_LATE_OTHER];

const ACCOUNT_OFFSET = 10; 
const ORACLES_COUNT = 30;

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);


flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
  if (error) {
    console.log(error);
  } else {
    
    let flightName = event.returnValues.flight;
    let timestamp = event.returnValues.timestamp;
    let statusCode = getRandomStatusCode();
    let index = event.returnValues.index;
    let airline = event.returnValues.airline;
    
    // Fetching Indexes for Oracle Accounts
    for (let i = 0; i < oracle_accounts.length; i++) {

      if (oracle_accounts[i].indexes.includes(index)) {
        console.log("Oracle matches a reaction to request: " + JSON.stringify(oracle_accounts[i]));
        
        // Submit Oracle Response
        flightSuretyApp.methods
          .submitOracleResponse(index, airline, flightName, timestamp, statusCode)
          .send({
            from: oracle_accounts[i].address,
            gas: 200000
          }, (error, result) => {
            if (error) {
              console.log(error);
            } else {
              console.log("Sent Oracle Response " + JSON.stringify(oracle_accounts[i]) + " With Status Code: " + statusCode);
            }
          });
      }
    }
  }
});

function getRandomStatusCode() {
  return STATUS_CODES[Math.floor(Math.random() * STATUS_CODES.length)];
}

// Registering the Oracles
web3.eth.getAccounts((error, accounts) => {
  if (accounts.length < ORACLES_COUNT + ACCOUNT_OFFSET) {
    throw "Increase the number of accounts"
  }

  // Register the Caller as Authorized
  flightSuretyData.methods
    .authorizeCaller(config.appAddress)
    .send({
      from: accounts[0]
    }, (error, result) => {
      if (error) {
        console.log(error);
      } else {
        console.log("Registered the caller as authorized.");
      }
    });

  // Resolve Oracle Registration Fee from Contract
  flightSuretyApp.methods
    .REGISTRATION_FEE()
    .call({
      from: accounts[0]
    }, (error, result) => {
      if (error) {
        console.log(error);
      } else {
        let registrationFee = result;
        // Register Oracle
        for (let idx = ACCOUNT_OFFSET; idx < ORACLES_COUNT + ACCOUNT_OFFSET; idx++) {
          flightSuretyApp.methods
            .registerOracle()
            .send({
              from: accounts[idx],
              value: registrationFee,
              gas: 3000000
            }, (reg_error, reg_result) => {
              if (reg_error) {
                console.log(reg_error);

              } else {
                // Fetch index for an oracle account
                flightSuretyApp.methods
                  .getMyIndexes()
                  .call({
                    from: accounts[idx]
                  }, (fetch_error, fetch_result) => {
                    if (error) {
                      console.log(fetch_error);

                    } else {
                      // Add a registered account to oracle account list
                      let oracle = {
                        address: accounts[idx],
                        indexes: fetch_result
                      };

                      oracle_accounts.push(oracle);
                      console.log("Oracle Registered: " + JSON.stringify(oracle));
                    }
                  });
              }
            });
        }
      }
    });
});

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


