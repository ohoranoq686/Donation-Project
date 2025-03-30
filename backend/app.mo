import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Hash "mo:base/Hash";
import Time "mo:base/Time";

actor ImpactChain {
    // Tipe data untuk kampanye
    type Campaign = {
        id: Nat;
        creator: Principal;
        title: Text;
        description: Text;
        goalAmount: Nat;
        currentAmount: Nat;
        deadline: Int;
        status: CampaignStatus;
        impacts: [Impact];
        donors: [Donation];
    };

    // Status kampanye
    type CampaignStatus = {
        #Pending;
        #Active;
        #Successful;
        #Failed;
    };

    // Tipe data donasi
    type Donation = {
        donor: Principal;
        amount: Nat;
        timestamp: Int;
    };

    // Tipe data dampak
    type Impact = {
        description: Text;
        evidenceUrl: Text;
        timestamp: Int;
    };

    // Penyimpanan kampanye
    private var campaigns = HashMap.HashMap<Nat, Campaign>(10, Nat.equal, Nat.hash);
    private var campaignCounter : Nat = 0;

    // Membuat kampanye baru
    public shared(msg) func createCampaign(
        title: Text, 
        description: Text, 
        goalAmount: Nat, 
        deadline: Int
    ) : async Result.Result<Nat, Text> {
        // Validasi input
        if (Text.size(title) == 0 or goalAmount == 0 or deadline <= Time.now()) {
            return #err("Invalid campaign details");
        };

        let newCampaign : Campaign = {
            id = campaignCounter;
            creator = msg.caller;
            title = title;
            description = description;
            goalAmount = goalAmount;
            currentAmount = 0;
            deadline = deadline;
            status = #Active;
            impacts = [];
            donors = [];
        };

        campaigns.put(campaignCounter, newCampaign);
        campaignCounter += 1;
        #ok(campaignCounter - 1)
    };

    // Fungsi donasi
    public shared(msg) func donate(
        campaignId: Nat, 
        amount: Nat
    ) : async Result.Result<Donation, Text> {
        switch (campaigns.get(campaignId)) {
            case null { return #err("Campaign not found"); };
            case (?campaign) {
                // Validasi kampanye masih aktif
                if (campaign.status != #Active or Time.now() > campaign.deadline) {
                    return #err("Campaign is not active");
                };

                let donation : Donation = {
                    donor = msg.caller;
                    amount = amount;
                    timestamp = Time.now();
                };

                let updatedCampaign : Campaign = {
                    id = campaign.id;
                    creator = campaign.creator;
                    title = campaign.title;
                    description = campaign.description;
                    goalAmount = campaign.goalAmount;
                    currentAmount = campaign.currentAmount + amount;
                    deadline = campaign.deadline;
                    status = if (campaign.currentAmount + amount >= campaign.goalAmount) 
                             #Successful else campaign.status;
                    impacts = campaign.impacts;
                    donors = Array.append(campaign.donors, [donation]);
                };

                campaigns.put(campaignId, updatedCampaign);
                #ok(donation)
            };
        };
    };

    // Menambahkan bukti dampak
    public shared(msg) func addImpact(
        campaignId: Nat, 
        description: Text, 
        evidenceUrl: Text
    ) : async Result.Result<Impact, Text> {
        switch (campaigns.get(campaignId)) {
            case null { return #err("Campaign not found"); };
            case (?campaign) {
                // Hanya pembuat kampanye yang bisa menambahkan dampak
                if (campaign.creator != msg.caller) {
                    return #err("Only campaign creator can add impacts");
                };

                let impact : Impact = {
                    description = description;
                    evidenceUrl = evidenceUrl;
                    timestamp = Time.now();
                };

                let updatedCampaign : Campaign = {
                    id = campaign.id;
                    creator = campaign.creator;
                    title = campaign.title;
                    description = campaign.description;
                    goalAmount = campaign.goalAmount;
                    currentAmount = campaign.currentAmount;
                    deadline = campaign.deadline;
                    status = campaign.status;
                    impacts = Array.append(campaign.impacts, [impact]);
                    donors = campaign.donors;
                };

                campaigns.put(campaignId, updatedCampaign);
                #ok(impact)
            };
        };
    };

    // Mendapatkan detail kampanye
    public query func getCampaign(campaignId: Nat) : async ?Campaign {
        campaigns.get(campaignId)
    };

    // Mendapatkan semua kampanye
    public query func getAllCampaigns() : async [(Nat, Campaign)] {
        Iter.toArray(campaigns.entries())
    };
}
