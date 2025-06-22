import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Int "mo:base/Int";

actor USSDGateway {

  type Transaction = {
    tx_type: Text;
    amount: Nat;
    to: ?Text;
    timestamp: Int;
  };

  type User = {
    phone: Text;
    pin: Text;
    balance: Nat;
    history: [Transaction];
  };

  type Saving = {
    amount: Nat;
    start_time: Int;
  };

  // Use var instead of stable var for HashMaps (they're not stable)
  private var users = HashMap.HashMap<Principal, User>(10, Principal.equal, Principal.hash);
  private var admins = HashMap.HashMap<Principal, Bool>(1, Principal.equal, Principal.hash);
  private var savings = HashMap.HashMap<Principal, Saving>(10, Principal.equal, Principal.hash);
  private var favorites = HashMap.HashMap<Principal, [Principal]>(10, Principal.equal, Principal.hash);

  // Initialize with a default admin (the deployer)
  public func init() : async () {
    // This would be called during deployment
  };

  public shared({ caller }) func register(phone: Text, pin: Text) : async Text {
    switch (users.get(caller)) {
      case (?_) return "Already registered.";
      case null {
        let newUser : User = {
          phone = phone;
          pin = pin;
          balance = 0;
          history = [];
        };
        users.put(caller, newUser);
        return "Registration successful.";
      };
    };
  };

  public shared({ caller }) func deposit(amount: Nat) : async Text {
    switch (users.get(caller)) {
      case null return "Not registered.";
      case (?user) {
        let newTransaction : Transaction = {
          tx_type = "Deposit";
          amount = amount;
          to = null;
          timestamp = Time.now();
        };
        let updatedUser : User = {
          phone = user.phone;
          pin = user.pin;
          balance = user.balance + amount;
          history = Array.append(user.history, [newTransaction]);
        };
        users.put(caller, updatedUser);
        return "Deposited " # Nat.toText(amount) # " ICP.";
      };
    };
  };

  public shared({ caller }) func balance() : async Text {
    switch (users.get(caller)) {
      case null return "User not registered.";
      case (?user) return "Balance: " # Nat.toText(user.balance) # " ICP.";
    };
  };

  public shared({ caller }) func transfer(to: Principal, amount: Nat) : async Text {
    if (Principal.equal(caller, to)) return "Cannot send to self.";
    
    switch (users.get(caller)) {
      case null return "Sender not registered.";
      case (?sender) {
        if (sender.balance < amount) return "Insufficient funds.";
        
        switch (users.get(to)) {
          case null return "Recipient not found.";
          case (?receiver) {
            let senderTransaction : Transaction = {
              tx_type = "Transfer Sent";
              amount = amount;
              to = ?Principal.toText(to);
              timestamp = Time.now();
            };
            
            let receiverTransaction : Transaction = {
              tx_type = "Transfer Received";
              amount = amount;
              to = ?Principal.toText(caller);
              timestamp = Time.now();
            };
            
            let updatedSender : User = {
              phone = sender.phone;
              pin = sender.pin;
              balance = sender.balance - amount;
              history = Array.append(sender.history, [senderTransaction]);
            };
            
            let updatedReceiver : User = {
              phone = receiver.phone;
              pin = receiver.pin;
              balance = receiver.balance + amount;
              history = Array.append(receiver.history, [receiverTransaction]);
            };
            
            users.put(caller, updatedSender);
            users.put(to, updatedReceiver);
            return "Transfer successful.";
          };
        };
      };
    };
  };

  public shared({ caller }) func resetPin(newPin: Text) : async Text {
    switch (users.get(caller)) {
      case null return "User not registered.";
      case (?user) {
        let updatedUser : User = {
          phone = user.phone;
          pin = newPin;
          balance = user.balance;
          history = user.history;
        };
        users.put(caller, updatedUser);
        return "PIN updated.";
      };
    };
  };

  public shared({ caller }) func history() : async [Transaction] {
    switch (users.get(caller)) {
      case null return [];
      case (?user) return user.history;
    };
  };

  public shared({ caller }) func buyAirtime(phoneNumber: Text, amount: Nat) : async Text {
    switch (users.get(caller)) {
      case null return "User not registered.";
      case (?user) {
        if (user.balance < amount) return "Insufficient funds.";
        
        let transaction : Transaction = {
          tx_type = "Buy Airtime for " # phoneNumber;
          amount = amount;
          to = null;
          timestamp = Time.now();
        };
        
        let updatedUser : User = {
          phone = user.phone;
          pin = user.pin;
          balance = user.balance - amount;
          history = Array.append(user.history, [transaction]);
        };
        
        users.put(caller, updatedUser);
        return "Airtime purchase successful.";
      };
    };
  };

  public shared({ caller }) func payBill(vendor: Text, amount: Nat) : async Text {
    switch (users.get(caller)) {
      case null return "User not registered.";
      case (?user) {
        if (user.balance < amount) return "Insufficient funds.";
        
        let transaction : Transaction = {
          tx_type = "Bill Payment to " # vendor;
          amount = amount;
          to = null;
          timestamp = Time.now();
        };
        
        let updatedUser : User = {
          phone = user.phone;
          pin = user.pin;
          balance = user.balance - amount;
          history = Array.append(user.history, [transaction]);
        };
        
        users.put(caller, updatedUser);
        return "Bill payment successful.";
      };
    };
  };

  public shared({ caller }) func saveFunds(amount: Nat) : async Text {
    switch (users.get(caller)) {
      case null return "Not registered.";
      case (?user) {
        if (user.balance < amount) return "Insufficient funds.";
        
        let updatedUser : User = {
          phone = user.phone;
          pin = user.pin;
          balance = user.balance - amount;
          history = user.history;
        };
        
        let newSaving : Saving = {
          amount = amount;
          start_time = Time.now();
        };
        
        users.put(caller, updatedUser);
        savings.put(caller, newSaving);
        return "Saved " # Nat.toText(amount) # " ICP.";
      };
    };
  };

  public shared({ caller }) func withdrawSavings() : async Text {
    switch (savings.get(caller)) {
      case null return "No savings.";
      case (?saving) {
        let interest = saving.amount / 10;
        let total = saving.amount + interest;
        
        switch (users.get(caller)) {
          case (?user) {
            let updatedUser : User = {
              phone = user.phone;
              pin = user.pin;
              balance = user.balance + total;
              history = user.history;
            };
            
            users.put(caller, updatedUser);
            savings.delete(caller);
            return "Withdrawn " # Nat.toText(total) # " ICP including interest.";
          };
          case null return "User not found.";
        };
      };
    };
  };

  public shared({ caller }) func addFavorite(p: Principal) : async Text {
    let currentFavs = switch (favorites.get(caller)) {
      case null [];
      case (?f) f;
    };
    
    // Check if already exists
    let alreadyExists = Array.find<Principal>(currentFavs, func(x) = Principal.equal(x, p));
    
    switch (alreadyExists) {
      case (?_) return "Already added.";
      case null {
        let newFavs = Array.append(currentFavs, [p]);
        favorites.put(caller, newFavs);
        return "Added to favorites.";
      };
    };
  };

  public shared({ caller }) func getFavorites() : async [Text] {
    switch (favorites.get(caller)) {
      case null return [];
      case (?f) {
        return Array.map<Principal, Text>(f, Principal.toText);
      };
    };
  };

  // === Admin Section ===
  public shared({ caller }) func addAdmin(p: Principal) : async Text {
    let isCallerAdmin = switch (admins.get(caller)) {
      case (?true) true;
      case _ false;
    };
    
    if (not isCallerAdmin) return "Unauthorized.";
    
    admins.put(p, true);
    return "Admin added.";
  };

  public shared({ caller }) func removeAdmin(p: Principal) : async Text {
    let isCallerAdmin = switch (admins.get(caller)) {
      case (?true) true;
      case _ false;
    };
    
    if (not isCallerAdmin) return "Unauthorized.";
    
    admins.delete(p);
    return "Admin removed.";
  };

  public shared({ caller }) func isAdmin() : async Bool {
    switch (admins.get(caller)) {
      case (?true) true;
      case _ false;
    };
  };

  public shared({ caller }) func getAllUsers() : async [Text] {
    let isCallerAdmin = switch (admins.get(caller)) {
      case (?true) true;
      case _ false;
    };
    
    if (not isCallerAdmin) return ["Unauthorized"];
    
    var phoneNumbers : [Text] = [];
    for ((principal, user) in users.entries()) {
      phoneNumbers := Array.append(phoneNumbers, [user.phone]);
    };
    return phoneNumbers;
  };

  // Helper function to set initial admin (call this after deployment)
  public shared({ caller }) func setInitialAdmin() : async Text {
    admins.put(caller, true);
    return "Initial admin set.";
  };
}
