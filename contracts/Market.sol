// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/** 
 * @title MyMarketplace
 * @dev Dario Sanchez
 */
contract Market {
   
    struct Service {
        ServiceMetadata metadata;
        address creatorId;
        address actualOwner;
        uint16 duration;
        uint buyMoment;
        bool sold;
    }

    struct ServiceMetadata {
        string title;
        string description;
        string icon;
        uint price;
    }

    struct Users {
        UserRole role;
        int16 reputation;
        string categories;
        string links;
    }

    enum UserRole { Professional, Employeer, Admin }


    // ************ MARKETPLACE *******************

    mapping(address => Users) public users;
    mapping(uint128 => Service) public services;
    uint64 public totalServices;

    address public owner;
    address public token;

    address[] public admins;

    // *************** EVENTS *********************

    event newUser(address account, UserRole rol, string categories);

    event newService(address creator, uint8 quantity);

    event newDispute(uint64 id, address employeer, address professional);


    // ************* MODIFIERS ********************

    modifier onlyOwner() { require(msg.sender == owner, "Only executable by the owner"); _; }

    modifier onlyProfessional() { require(users[msg.sender].role == UserRole.Professional, "Only executable by a professional"); _; }

    modifier onlyEmployeer() { require(users[msg.sender].role == UserRole.Employeer, "Only executable by a employeer"); _; }

    // ************************************************
    // ************** CORE FUNCTIONS ******************
    // ************************************************

    constructor() {
        owner = msg.sender;
    }

    function addUser(UserRole _role, string memory _categories, string memory _links) public {
        // Verify that not want be a Admin
        require(_role != UserRole.Admin, "Without permissions to be Admin");

        users[msg.sender] = Users({
            role: _role,
            reputation: 0,
            categories: _categories,
            links: _links
        });
        emit newUser(msg.sender, _role, _categories);
    }

    /** @dev Add a new user created to the owner.
     *  Used to add Admins.
     */
    function addUserByOwner(
        address _user,
        UserRole _role, 
        string memory _categories, 
        string memory _links) 
        public onlyOwner 
        {
        users[_user] = Users({
            role: _role,
            reputation: 0,
            categories: _categories,
            links: _links
        });
        emit newUser(_user, _role, _categories);
    }

    /** @dev Add a new user after verification by KYC.
     *  Init with aditional reputation to can be jury member.
     *  Only for Admins.
     */
    function addUserWithKYC(
        address _user,
        UserRole _role, 
        string memory _categories, 
        string memory _links) 
        public onlyOwner 
        {
        users[_user] = Users({
            role: _role,
            reputation: 3,
            categories: _categories,
            links: _links
        });
        emit newUser(_user, _role, _categories);
    }


    /** Create a new service or a indicate amount of these.
     *  Only for professionals.
     */
    function createService(
        ServiceMetadata memory _metadata, 
        uint8 _quantity, 
        uint16 _duration) 
        public onlyProfessional 
        {
        for(uint8 i = 0; i < _quantity; i++) {
            services[totalServices] = Service({
                metadata: _metadata,
                creatorId: msg.sender,
                actualOwner: msg.sender,
                duration: _duration,
                buyMoment: block.timestamp,
                sold: false
            });
            totalServices += 1;
        }
        emit newService(msg.sender, _quantity);
    }

    /** Buy a service by a employeer.
     *  Tokens are temporary blocked in mediator contract.
     */
    function buyService(uint128 _id) public payable onlyEmployeer {
        require(totalServices >=_id, "The indicated service don't exist");
        Service storage service = services[_id];

        // Verify that service is not buyed and is on sale
        require(service.actualOwner == service.creatorId, "The service isn't on sale");

        // Modify the service data
        service.sold = true;
        service.actualOwner = msg.sender;
        service.buyMoment = block.timestamp;

        // TODO transfer tokens to mediator
    }


    /** Approve a realized work.
     *  Set a punctuation for the professional.
     *  Transfer the blocked tokens for mediator to the professional.
     *  Auto increace of employeer reputation in 2 points.
     */
    function approveService(uint64 _id, int8 _points) public onlyEmployeer returns(bool) {
        require(totalServices >=_id, "The indicated service don't exist");

        // Verify that points are between -4 and 4
        require(_points > -5 && _points < 5, "Puntuation must be between -5 and 5");

        Service storage service = services[_id];

        // Verify that is the service owner
        require(service.actualOwner == msg.sender, "The service isn't your");

        // Modify the service data
        service.sold = false;
        service.actualOwner = msg.sender;
        service.buyMoment = 0;

        users[service.actualOwner].reputation += _points;
        users[msg.sender].reputation += 2;

        // TODO send the tokens

        return true;
    }


    /** Reclaim a service by the employeer
     *  Send the data and the control to the mediator contract
     */
    function reclaimDispute(uint64 _id) public payable onlyEmployeer returns(bool) {
        require(totalServices >=_id, "The indicated service don't exist");
        Service storage service = services[_id];

        // Verify that the service was buyed
        require(service.actualOwner == msg.sender, "You don't peosee the indicated service");

        // TODO pay tokens according the desired jury amount 

        emit newDispute(_id, msg.sender, service.creatorId);
        return true;
    }


    /** Return a service after aprovation of professional and employeer
     *  Only executable by the admin of professional creator of the service
     */ 
    function returnService(uint128 _id) public returns(bool) {
        require(totalServices >=_id, "The indicated service don't exist");
        Service storage service = services[_id];

        // Verify who call the function
        require(msg.sender == owner || msg.sender == service.creatorId, 
        "You don't have permission to call this function");

        // Verify that the service was sold
        require(service.actualOwner != service.creatorId, "The service isn't was sold");

        // Modify the service data
        service.sold = false;
        service.actualOwner = service.creatorId;
        service.buyMoment = 0;

        // TODO return the tokens to the employeer

        return true;
    }


    // ************************************************
    // ************** SET FUNCTIONS *******************
    // ************************************************

    /** Change the service duration
     *  Only executable by the professional while is owner of the service
     */
    function setServiceDuration(uint128 _id, uint16 _duration) public onlyProfessional returns(bool) {
        require(totalServices >=_id, "The indicated service don't exist");
        Service storage service = services[_id];

        // Verify that the service wasn't sold
        require(service.actualOwner == service.creatorId, "The service was sold");

        // Modify the service data
        service.duration = _duration;

        return true;
    }


    /** Change the service metadata
     *  Only executable by the professional while is owner of the service
     */
    function setServiceDuration(uint128 _id, ServiceMetadata memory _metadata) 
        public onlyProfessional returns(bool) 
        {
        require(totalServices >=_id, "The indicated service don't exist");
        Service storage service = services[_id];

        // Verify that the service wasn't sold
        require(service.actualOwner == service.creatorId, "The service was sold");

        // Modify the service data
        service.metadata = _metadata;

        return true;
    }


    // ************************************************
    // ************** GET FUNCTIONS *******************
    // ************************************************

    /** @dev Get the most important dates of a service.
     *  @return creator and actual owner, times and bools.
     */
    function getServiceById(uint64 _id) 
        public view returns(address, address, uint16, uint, bool) 
        {
        return (
            services[_id].creatorId, 
            services[_id].actualOwner, 
            services[_id].duration, 
            services[_id].buyMoment, 
            services[_id].sold
        );
    }

}