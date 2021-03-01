pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

                /************************************************** */
                /*              FlightSurety Smart Contract         */
                /************************************************** */

contract FlightSuretyData {
    address [] public insurees;

    function isOperational() public view returns(bool);
    function isCallerAirlineRegistered(address originSender) public view returns (bool);
    function isCallerAirlineFunded(address originSender) public view returns (bool);
    function isFlightInsured(address originSender, address airline, string flightNumber, uint256 timestamp) public view returns (bool);

    function registerAirline(address originSender, address airline) external returns (bool success);
    function fundAirline(address airline) external;

    function fetchInsureeAmount(address originSender,address airline,string flightNumber,uint256 timestamp) external view returns (uint256);

    function insureeBalance(address originSender) external view returns (uint256);
    function buy(address originSender, address airline, string flightNumber, uint256 timestamp, uint256 amount) external;
    function creditInsurees(address airline, string flightNumber, uint256 timestamp) external;

    function pay(address originSender) external;
}

contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)
    using SafeMath for uint8; // Allow SafeMath functions to be called for all uint8 types

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    // Account used to deploy contract
    address private contractOwner;

    // Instance for FlightSuretyData
    FlightSuretyData flightSuretyData;          

    // Minimum and Maximum Value for Funds
    uint256 public constant MAX_AIRLINE_FUND = 10 ether;
    uint256 public constant MIN_AIRLINE_FUND = 8 ether;

    // Maximum parties that can take part in consensus
    uint256 private constant MULTIPARTY_CONSENSUS_LIMIT = 4;

    // Maximum Insurance Payment
    uint256 private constant MAX_INSURANCE_PAYMENT = 1 ether;

    // Variable to store the number of airlines
    uint8 public registeredAirlinesCount;

    // Structure for Flight Details
    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }

    // Mapping to relate the flight code with flight details
    mapping(bytes32 => Flight) private flights;

    // Mapping to relate the votes earned by an airline during consensus
    mapping(address => address[]) private airlineVotes;


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
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
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
    * @dev Modifier that requires the function caller is Insured
    */
    modifier requireFlightNotInsured(address airline, string flightNumber, uint256 timestamp)
    {
        require(!flightSuretyData.isFlightInsured(msg.sender, airline, flightNumber, timestamp), "Flight already insured");
        _;
    } 
    
    /**
    * @dev Modifier that requires the Caller Airline is registered
    */
    modifier requireIsCallerAirlineRegistered()
    {
        require(flightSuretyData.isCallerAirlineRegistered(msg.sender), "Caller not registered");
        _;
    }

    /**
    * @dev Modifier that requires the "Caller Airline" has submitted the funds
    */
    modifier requireIsCallerAirlineFunded()
    {
        require(flightSuretyData.isCallerAirlineFunded(msg.sender), "Caller can not participate in contract until it submits funding");
        _;
    }


    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataContract
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        registeredAirlinesCount = 1;
        flightSuretyData = FlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            pure 
                            returns(bool) 
    {
        return true;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    */   
    function registerAirline
                            (   
                                address airlineAdress
                            )
                            external
                            requireIsCallerAirlineFunded
                            requireIsOperational
                            requireIsCallerAirlineRegistered
    {
        // Initializing the result (success) as false
        bool success = false;

        // Checking if the number of airlines are lesser than the maximum airlines allowed
        if(registeredAirlinesCount < MULTIPARTY_CONSENSUS_LIMIT) {
            success = flightSuretyData.registerAirline(msg.sender, airline);
            if(success) { // If the airline is registered, we increment the 
                registeredAirlinesCount++;
            }
        } else {
            // Initializing the duplicate flag as false
            bool isDuplicate = false;

            for(uint i = 0; i < airlineVotes[airline].length; i++) {
                // Checking if the airline is already registered
                if (airlineVotes[airline][i] == msg.sender) {
                    isDuplicate = true;
                    break;
                }
            }

            // If the airline is already registered, i.e. it is duplicate, then return "Multivotes not allowed"
            require(!isDuplicate, "Multivotes not allowed");

            // If the airline is not a duplicate, we add it in the list
            airlineVotes[airline].push(msg.sender);

            if (airlineVotes[airline].length >= registeredAirlinesCount.div(2)) {

                success = flightSuretyData.registerAirline(msg.sender, airline);
                if(success) {
                    airlinesRegisteredCount++;
                }

                airlineVotes[airline] = new address[](0);
            }
        }
    }

   /**
    * @dev Register a future flight for insuring.
    */  
    function registerFlight
                                (
                                    address airlineAddress,
                                    string flightNumber,
                                    uint256 timestamp
                                )
                                public
                                payable
                                requireFlightNotAssured(airlineAddress, flightNumber, timestamp)
                                requireIsOperational

    {
        require(msg.value <= MAX_INSURANCE_PAYMENT, "Maximum sum insured exceeded");

        // Transferring Payment to Data Contract
        address(flightSuretyData).transfer(msg.value);

        flightSuretyData.buy(msg.sender, airlineAddress, flightNumber, timestamp, msg.value);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    */  
    function processFlightStatus
                                (
                                    address airlineAddress,
                                    string memory flightNumber,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
                                requireIsOperational
    {
        if(statusCode == STATUS_CODE_LATE_AIRLINE) {
            flightSuretyData.creditInsurees(airlineAddress, flightNumber, timestamp);
        }
    }

   /**
    * @dev Generate a request for oracles to fetch flight information
    */
    function fetchFlightStatus
                        (
                            address airlineAddress,
                            string flightNumber,
                            uint256 timestamp                            
                        )
                        external
                        requireIsOperational
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airlineAddress, flightNumber, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true,
                                                isValid: true
                                            });

        emit OracleRequest(index, airlineAddress, flightNumber, timestamp);
    } 

   /**
    * @dev Transfer the fund for the airline
    */
    function fundAirline 
                            (
                            )
                            public
                            payable
                            requireIsOperational
    {
        require(msg.value >= MAX_AIRLINE_FUND, "Seed fund required or too low");

        // Transfer Fund to Data Contract
        address(flightSuretyData).transfer(msg.value);
        flightSuretyData.fundAirline(msg.sender);
    }

   /**
    * @dev Generate a request for oracles to fetch flight information
    */
    function insureeBalance
                            (
                            )
                            external
                            view
                            requireIsOperational
                            returns (uint256)
    {
        return flightSuretyData.insureeBalance(msg.sender);
    }

   /**
    * @dev Withdraw amount from the Airlines account
    */
    function withdraw
                            (
                            )
                            external
                            requireIsOperational
    {
        flightSuretyData.pay(msg.sender);
    } 

    /********************************************************************************************/
    /*                                       ORACLE MANAGEMENT                                  */
    /********************************************************************************************/

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);

    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
                            requireIsOperational
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airlineAddress,
                            string flightNumber,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
                        requireIsOperational
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airlineAddress, flightNumber, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        if(oracleResponses[key].isOpen) {
            oracleResponses[key].responses[statusCode].push(msg.sender);

            // Information isn't considered verified until at least MIN_RESPONSES
            // oracles respond with the *** same *** information
            emit OracleReport(airlineAddress, flightNumber, timestamp, statusCode);
            if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

                // if Response is verified close request
                oracleResponses[key].isOpen = false;

                emit FlightStatusInfo(airlineAddress, flightNumber, timestamp, statusCode);

                // Handle flight status as appropriate
                processFlightStatus(airlineAddress, flightNumber, timestamp, statusCode);
            }
        }
    }


    function getFlightKey
                        (
                            address airlineAddress,
                            string flightNumber,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airlineAddress, flightNumber, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   
