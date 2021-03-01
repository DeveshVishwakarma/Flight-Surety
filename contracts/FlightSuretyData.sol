pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => uint256) private authorizedCallers;              
    mapping (address => Airline) private airlines;
    mapping (bytes32 => FlightInsurance) private flightInsurances;
    mapping (address => uint256) private insureeBalances;
    mapping (bytes32 => address[]) private insureesMap;

    struct Airline {
        bool isRegistered;
        bool isFunded;
    }

    struct FlightInsurance {
        uint256 amount;
        bool isInsured;
        bool isCredited;      
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address firstAirline
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        airlines[firstAirline] = Airline({isRegistered: true, isFunded: false});
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier that requires the function caller flight to be insured
    */
    modifier requireFlightNotInsured(address sender, address airlineAddress, string flightNumber, uint256 timestamp)
    {
        require(!isFlightInsured(sender, airlineAddress, flightNumber, timestamp), "Flight already insured");
        _;
    }

    /**
    * @dev Modifier that requires the function caller airline to be registered
    */
    modifier requireIsCallerAirlineRegistered(address sender)
    {
        require(isCallerAirlineRegistered(sender), "Caller not registered");
        _;
    }

    /**
    * @dev Modifier that requires the function caller to be authorized
    */
    modifier requireIsCallerAuthorized()
    {
        require(authorizedCallers[msg.sender] == 1 || msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier that requires the function caller airline to be submit the funds
    */
    modifier requireIsCallerAirlineFunded(address sender)
    {
        require(isCallerAirlineFunded(sender), "Caller cannot participate in contract until it submits funding");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /**
    * @dev Get registered status of airline
    *
    * @return A bool that is the registration status of the airline
    */
    function isCallerAirlineRegistered 
                                        (
                                            address airline
                                        )
                                        public
                                        view
                                        returns (bool)
    {
        return airlines[airline].isRegistered;
    }

    /**
    * @dev Get funding status of airline
    *
    * @return A bool that is the current funding status of the airline
    */
    function isAirlineFunded 
                                (
                                    address airline
                                )
                                public
                                view
                                returns (bool)
    {
        return airlines[airlineAddress].isFunded;
    }

    /**
    * @dev Get insured status of flight
    *
    * @return A bool that is the current insurance status of the flight
    */
    function isFlightInsured 
                                (
                                    address airline,
                                    address airlineAddress,
                                    string flightNumber,
                                    uint256 timestamp
                                )
                                public
                                view
                                returns (bool)
    {
        FlightInsurance storage insurance = flightInsurances[getInsuranceKey(airline, airlineAddress, flightNumber, timestamp)];
        return insurance.isInsured;
    }

    /**
    * @dev Make the caller authorized 
    */
    function authorizeCaller
                                (
                                    address externalAddress
                                )
                                external requireContractOwner
    {
        authorizedCallers[externaltAddress] = 1;
    }

    /**
    * @dev Revoke the authorized status of the caller
    */
    function deauthorizeCaller
                                (
                                    address externalAddress
                                )
    {
        delete authorizedCallers[externalAddress];
    }

    /**
    * @dev Get authorization status of caller
    *
    * @return A bool that is the current authorization status
    */
    function isAuthorizedCaller
                                (
                                    address externalAddress
                                )
    {
        return authorizedCallers[externaltAddress] == 1;
    }   

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    * 
    *   Can only be called from FlightSuretyApp contract
    */   
    function registerAirline
                            (   
                                address sender,
                                address airlineAddress
                            )
                            external
                            requireIsCallerAirlineRegistered(sender)
                            requireIsCallerAirlineFunded(sender)
                            requireIsCallerAuthorized
                            requireisOperational
                            returns (bool success)
    {
        require(!airlines[airlineAddress].isRegistered, "Airline is already registered");
        airlines[airlineAddress] =  Airline({isRegistered: true, isFunded: false});
        return airlines[airlineAddress].isRegistered;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (     
                                address sender,
                                address airlineAddress,
                                string flightNumber,
                                uint256 timestamp,
                                uint256 amount                        
                            )
                            external
                            requireIsCallerAuthorized
                            requireIsOperational
                            requireFlightNotInsured(sender, airlineAddress, flightNumber, timestamp)
    {
        FlightInsurance storage insurance = flightInsurances[getInsuranceKey(sender, airlineAddress, flightNumber, timestamp)];
        insurance.isInsured = true;
        insurance.amount = amount;
        appendInsuree(sender, airline, flightNumber, timestamp);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address airlineAddress,
                                    string flightNumber,
                                    uint256 timestamp
                                )
                                external
                                requireIsCallerAuthorized
                                requireIsOperational
    {
        address [] storage insurees = insureesMap[getInsuranceKey(0x0, airlineAddress, flightNumber, timestamp)];

        for(uint i = 0; i < insurees.length; i++) {
            FlightInsurance storage insurance = flightInsurances[getInsuranceKey(insurees[i], airlineAddress, flightNumber, timestamp)];

            // if instead of require so that a single mistake does not endanger the payouts of other policyholders
            if(insurance.isInsured && !insurance.isCredited) {
                insurance.isCredited = true;
                insureeBalances[insurees[i]] = insureeBalances[insurees[i]].add(insurance.amount.mul(15).div(10));
            }
        }
    }
    
    function insureeBalance
                            (
                                address sender
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
                            view
                            returns (uint256)
    {
        return insureeBalances[sender];
    }

    function appendInsuree
                            (
                                address sender,
                                address airlineAddress,
                                string flightNumber,
                                uint256 timestamp
                            )
                            internal
                            requireIsOperational
    {
        address [] storage insurees = insureesMap[getInsuranceKey(0x0, airlineAddress, flightNumber, timestamp)];
        bool duplicate = false;
        for(uint256 i = 0; i < insurees.length; i++) {
            if(insurees[i] == sender) {
                duplicate = true;
                break;
            }
        }

        if(!duplicate) {
            insurees.push(sender);
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                address sender
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
    {
        require(address(this).balance > insureeBalances[sender], "Contract is out of funds");

        uint256 temp = insureeBalances[sender];
        insureeBalances[sender] = 0;
        sender.transfer(temp);
    }

   /**
    *@dev get address balance
    *
    *
    */
    function getBalance
                            (
                            )
                            public
                            view
                            requireIsOperational
                            requireContractOwner
                            returns (uint256)
    {
        return address(this).balance;
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
    {
    }

    /**
    *@dev Fund an airline
    *
    */
    function fundAirline
                            (
                                address airlineAddress
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
    {
        airlines[airlineAddress].isFunded = true;
    }

    function getInsuranceKey
                        (
                            address insuree,
                            address airlineAddress,
                            string memory flightNumber,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(insuree, airlineAddress, flightNumber, timestamp));
    }

    function getFlightKey
                        (
                            address airlineAddress,
                            string memory flightNumber,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airlineAddress, flightNumber, timestamp));
    }

   /**
    * @dev Check if first airline is registered
    * 
    * @return bool
    */
    function isFirstAirlineRegistered(address firstAirline)
                            external
                            view  
                            requireIsOperational
                            returns(bool)
    {
        return airlines[firstAirline].isRegistered;
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

