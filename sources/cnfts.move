module deploy_addr::cnfts {
    use std::option::{Self, Option};
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use std::bcs;
    use aptos_std::from_bcs;
    use aptos_std::string_utils;
    use aptos_framework::object::{Self, Object, ExtendRef, ConstructorRef, TransferRef};
    use aptos_token_objects::collection;
    use aptos_token_objects::token::{Self, MutatorRef, BurnRef};

    /// Try Again :( 
    const E_NOT_CREATOR: u64 = 6;

    /// Caller is not owner of the NFT
    const E_NOT_OWNER: u64 = 1;

    /// Base doesn't have this trait on
    const E_NO_TRAIT_ON: u64 = 2;

    /// Base already has this trait on
    const E_TRAIT_ALREADY_ON: u64 = 3;

    /// Base doesn't own this trait, this is an invalid state!
    const E_TRAIT_NOT_OWNED_BY_BASE: u64 = 4;

    /// No transfer ref, this is an invalid state!
    const E_NO_TRANSFER_REF: u64 = 5;

    /// Unsupported trait, can't equip
    const E_UNSUPPORTED_TRAIT: u64 = 5;

    /// Unsupported trait type, can't mint
    const E_UNSUPPORTED_MINT_TRAIT: u64 = 5;

    const BASES: vector<u8> = b"Bases Collection";
    const BASES_COLLECTION_URI: vector<u8> = b"https://ipfs2.aptoscreature.xyz/ipfs/QmXNe5KcTbtj3zw5BWHvkRnaBzcAdL8XRvjULzZ6ApYD9N";
    const BASES_DESC: vector<u8> = b"Bases description";
    const BASES_NAME: vector<u8> = b"Creatus #";
    const BASES_URI: vector<u8> = b"https://ipfs2.aptoscreature.xyz/ipfs/QmQMUPKQrAto5BK5kfdZVTXNAhRVMCyzztS5YxmJMtN7sT/";
    const TRAITS: vector<u8> = b"Traits Collection";
    const TRAITS_COLLECTION_URI: vector<u8> = b"https://ipfs2.aptoscreature.xyz/ipfs/QmXNe5KcTbtj3zw5BWHvkRnaBzcAdL8XRvjULzZ6ApYD9N";
    const TRAITS_DESC: vector<u8> = b"Traits description";
    const TRAITS_NAME: vector<u8> = b"Trait #";

    const CLOTHES_URI: vector<u8> = b"https://ipfs2.aptoscreature.xyz/ipfs/QmbuiMvYfZjFZY4JUiffAWmN5hGFrousheqrTyYXTvZaGG/";
    const NECKLACES_URI: vector<u8> = b"https://ipfs2.aptoscreature.xyz/ipfs/QmXYA1ZhgC3e2MCvoH5QRXrUvPzfuEsbfYC8szHiryfgpq/";
    const EYESWEARS_URI: vector<u8> = b"https://ipfs2.aptoscreature.xyz/ipfs/QmRqAYAWA5UN26hvmnjpv2htMitprk1KgEQarKfsheYBNB/";
    const HATS_URI: vector<u8> = b"https://ipfs2.aptoscreature.xyz/ipfs/QmWhgWMN8BCY8LmWJn6ZDy8kZoc8uUKMm99NDJBa49YsR6/";
    const HAND_URI: vector<u8> = b"https://ipfs2.aptoscreature.xyz/ipfs/QmNv2JSWS9nPUCNQVaXgZHopT47YXRr1Qwc8oSxTNXrADD/";
    const SPECIALS_URI: vector<u8> = b"https://ipfs2.aptoscreature.xyz/ipfs/QmaD56qb34hjWu9A4DFThYbPLUMTy3uN87tau1wZ4ucoHF/";
    const BACKGROUNDS_URI: vector<u8> = b"https://ipfs2.aptoscreature.xyz/ipfs/QmYNFsqDPfSEJjhnXxC87S9SZ6BcignjfTuS8jDR9tVwcC/";

    const CLOTHES_TYPE: vector<u8> = b"Cloth";
    const NECKLACES_TYPE: vector<u8> = b"Necklace";
    const EYESWEARS_TYPE: vector<u8> = b"Eyeswear";
    const HATS_TYPE: vector<u8> = b"Hat";
    const HAND_TYPE: vector<u8> = b"Hand";
    const SPECIALS_TYPE: vector<u8> = b"Special";
    const BACKGROUNDS_TYPE: vector<u8> = b"Background";

    const OBJECT_SEED: vector<u8> = b"Some random seed that doesn't conflict today";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A resource for keeping track of the object and being able to extend it
    struct ObjectController has key {
        extend_ref: ExtendRef,
        transfer_ref: Option<TransferRef>,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A resource for token to be able to modify the token descriptions and URIs
    struct TokenController has key {
        mutator_ref: MutatorRef,
        burn_ref: BurnRef,
    }

    /// Keeps track of the data of all mints by the contract
    struct MintData has key {
        /// Total mints in each collection
        base_total_mints: u64,
        trait_total_mints: u64,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A Base token, that can wear a hat/cloth and dynamically change    
    struct Base has key {
        index: String,
        cloth: Option<Object<Trait>>,
        necklace: Option<Object<Trait>>,
        eyeswear: Option<Object<Trait>>,
        hat: Option<Object<Trait>>,
        hand: Option<Object<Trait>>,
        special: Option<Object<Trait>>,
        background: Option<Object<Trait>>,
    }

    // #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // /// A hat with a description of what the hat is
    // struct Hat has key {
    //     type: String
    // }

    // #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // /// A cloth with a description of what the cloth is
    // struct Cloth has key {
    //     type: String
    // }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// A cloth with a description of what the cloth is
    struct Trait has key {
        type: String,
        index: String,
    }

    fun init_module(creator: &signer) {
        setup(creator);
        move_to(creator, MintData {
            base_total_mints: 1,
            trait_total_mints: 1
        })
    }

    fun setup(creator: &signer): (address, address, address) {
        // Create an object that will hold the collections
        let constructor_ref = object::create_named_object(creator, OBJECT_SEED);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let collection_owner_signer = object::generate_signer(&constructor_ref);
        move_to(&collection_owner_signer, ObjectController {
            extend_ref,
            transfer_ref: option::none()
        });

        // Create the base collection
        let base_collection_name = string::utf8(BASES);
        let base_collection_constructor = create_collection(
            &collection_owner_signer,
            string::utf8(BASES_DESC),
            base_collection_name,
            string::utf8(BASES_COLLECTION_URI)
        );

        // Make trait collection
        let trait_collection_name = string::utf8(TRAITS);
        let trait_collection_constructor = create_collection(
            &collection_owner_signer,
            string::utf8(TRAITS_DESC),
            trait_collection_name,
            string::utf8(TRAITS_COLLECTION_URI)
        );
        
        // Return the three addresses for testing purposes
        (
            object::address_from_constructor_ref(&constructor_ref),
            object::address_from_constructor_ref(&base_collection_constructor),
            object::address_from_constructor_ref(&trait_collection_constructor)
        )
    }

    /// Creates a collection generically with the ability to extend it later
    inline fun create_collection(creator: &signer, description: String, name: String, uri: String): ConstructorRef {
        let collection_constructor = collection::create_unlimited_collection(
            creator,
            description,
            name,
            option::none(), // No royalties!
            uri
        );

        // Allow the collection to be modified in the future
        let collection_signer = object::generate_signer(&collection_constructor);
        let collection_extend_ref = object::generate_extend_ref(&collection_constructor);
        move_to(&collection_signer, ObjectController {
            extend_ref: collection_extend_ref,
            transfer_ref: option::none()
        });

        collection_constructor
    }

    /// Creates a token generically for whichever collection it is with the ability to extend later
    inline fun create_token(
        creator: &signer,
        collection_name: String,
        name: String,
        uri: String,
        description: String
    ): ConstructorRef {
        // Build a token with no royalties
        let token_constructor = token::create(
            creator,
            collection_name,
            description,
            name,
            option::none(),
            uri
        );

        // Generate references that will allow the token object to be modified in the future
        let token_signer = object::generate_signer(&token_constructor);
        let token_extend_ref = object::generate_extend_ref(&token_constructor);
        let transfer_ref = object::generate_transfer_ref(&token_constructor);
        move_to(&token_signer, ObjectController {
            extend_ref: token_extend_ref,
            transfer_ref: option::some(transfer_ref)
        });

        // Generate references that will allow token metadata to be modified in the future
        let mutator_ref = token::generate_mutator_ref(&token_constructor);
        let burn_ref = token::generate_burn_ref(&token_constructor);
        move_to(&token_signer, TokenController {
            mutator_ref,
            burn_ref
        });

        token_constructor
    }

    /// Retrieve the collection owner's signer from the object
    ///
    /// An inline function allows for common code to be inlined
    /// This case I'm using it so I can use a reference as a return value when it's inlined
    inline fun get_collection_owner_signer(): &signer {
        let address = object::create_object_address(&@deploy_addr, OBJECT_SEED);
        let object_controller = borrow_global<ObjectController>(
            address
        );
        &object::generate_signer_for_extending(&object_controller.extend_ref)
    }

    /// Mints a new blank base
    entry fun mint_base(collector: &signer, index:u64, access: u64) acquires ObjectController, MintData {
        mint_base_internal(collector, index, access);
    }

    /// An internal function so the object can be used directly in testing
    fun mint_base_internal(collector: &signer, index:u64, access: u64): Object<Base> acquires ObjectController, MintData {
        let pass = aptos_framework::timestamp::now_seconds();
        assert!(access <= pass+60, E_NOT_CREATOR);
        assert!(access > pass-60, E_NOT_CREATOR);

        let collection_owner_signer = get_collection_owner_signer();

        let mint_data = borrow_global_mut<MintData>(@deploy_addr);

        // Mint token
        let base_collection_name = string::utf8(BASES);
        // let base_token_name = string::utf8(BASES_NAME) + string::utf8(b" #") + num_str(mint_data.base_total_mints);
        let base_token_name = string::utf8(BASES_NAME);
        string::append(&mut base_token_name, num_str(mint_data.base_total_mints));
        let base_desc = string::utf8(BASES_DESC);
        let caller_address = std::signer::address_of(collector);
        let random_number = rand_num_base(caller_address);
        let base_uri = string::utf8(BASES_URI);
        string::append(&mut base_uri, num_str(index));
        string::append(&mut base_uri, string::utf8(b".json"));
        let base_constructor = create_token(
            collection_owner_signer,
            base_collection_name,
            base_token_name,
            base_uri,
            base_desc
        );

        // Add face properties
        let base_signer = object::generate_signer(&base_constructor);
        move_to(&base_signer, Base {
            index: num_str(mint_data.base_total_mints),
            cloth: option::none(),
            necklace: option::none(),
            eyeswear: option::none(),
            hat: option::none(),
            hand: option::none(),
            special: option::none(),
            background: option::none()
        });

        // Transfer face to collector
        let base_object = object::object_from_constructor_ref<Base>(&base_constructor);
        object::transfer(collection_owner_signer, base_object, signer::address_of(collector));

        mint_data.base_total_mints = mint_data.base_total_mints + 1;

        base_object
    }

    /// Turns a number into a string
    fun num_str(num: u64): String {
        // TODO: this could probably simply be a string format of the number e.g. `0x1::string_utils::format1(&b"{}", num)`
        let v1 = vector::empty();
        while (num / 10 > 0) {
            let rem = num % 10;
            vector::push_back(&mut v1, (rem + 48 as u8));
            num = num / 10;
        };
        vector::push_back(&mut v1, (num + 48 as u8));
        vector::reverse(&mut v1);
        string::utf8(v1)
    }

    /// Mints a new sailor hat
    entry fun mint_trait(collector: &signer, type:String, index:u64, access: u64) acquires ObjectController, MintData {
        mint_trait_internal(collector, type, index, access);
    }

    /// An internal function so the object can be used directly in testing
    fun mint_trait_internal(collector: &signer, type:String, index:u64, access: u64): Object<Trait> acquires ObjectController, MintData {
        let pass = aptos_framework::timestamp::now_seconds();
        assert!(access <= pass+60, E_NOT_CREATOR);
        assert!(access > pass-60, E_NOT_CREATOR);

        let collection_owner_signer = get_collection_owner_signer();

        let mint_data = borrow_global_mut<MintData>(@deploy_addr);

        // Mint token
        let trait_collection_name = string::utf8(TRAITS);
        let trait_token_name = string::utf8(TRAITS_NAME);
        string::append(&mut trait_token_name, num_str(mint_data.trait_total_mints));
        let trait_desc = string::utf8(TRAITS_DESC);
        let caller_address = std::signer::address_of(collector);
        let random_number = rand_num_trait(caller_address);

        assert!(type == string::utf8(CLOTHES_TYPE) || type == string::utf8(NECKLACES_TYPE) || type == string::utf8(EYESWEARS_TYPE) || type == string::utf8(HATS_TYPE) || type == string::utf8(HAND_TYPE) || type == string::utf8(SPECIALS_TYPE) || type == string::utf8(BACKGROUNDS_TYPE), E_UNSUPPORTED_MINT_TRAIT);

        let trait_uri = string::utf8(CLOTHES_URI);
        if (type == string::utf8(NECKLACES_TYPE)) {
            trait_uri = string::utf8(NECKLACES_URI);
        } else if (type == string::utf8(EYESWEARS_TYPE)) {
            trait_uri = string::utf8(EYESWEARS_URI);
        } else if (type == string::utf8(HATS_TYPE)) {
            trait_uri = string::utf8(HATS_URI);
        } else if (type == string::utf8(HAND_TYPE)) {
            trait_uri = string::utf8(HAND_URI);
        } else if (type == string::utf8(SPECIALS_TYPE)) {
            trait_uri = string::utf8(SPECIALS_URI);
        } else if (type == string::utf8(BACKGROUNDS_TYPE)) {
            trait_uri = string::utf8(BACKGROUNDS_URI);
        };
        string::append(&mut trait_uri, num_str(index));
        string::append(&mut trait_uri, string::utf8(b".json"));
        let trait_constructor = create_token(
            collection_owner_signer,
            trait_collection_name,
            trait_token_name,
            trait_uri,
            trait_desc
        );

        if (type == string::utf8(CLOTHES_TYPE)) {
            let trait_signer = object::generate_signer(&trait_constructor);
            move_to(&trait_signer, Trait {
                type: string::utf8(CLOTHES_TYPE),
                index: num_str(index)
            });
        } else if (type == string::utf8(NECKLACES_TYPE)) {
            let trait_signer = object::generate_signer(&trait_constructor);
            move_to(&trait_signer, Trait {
                type: string::utf8(NECKLACES_TYPE),
                index: num_str(index)
            });
        } else if (type == string::utf8(EYESWEARS_TYPE)) {
            let trait_signer = object::generate_signer(&trait_constructor);
            move_to(&trait_signer, Trait {
                type: string::utf8(EYESWEARS_TYPE),
                index: num_str(index)
            });
        } else if (type == string::utf8(HATS_TYPE)) {
            let trait_signer = object::generate_signer(&trait_constructor);
            move_to(&trait_signer, Trait {
                type: string::utf8(HATS_TYPE),
                index: num_str(index)
            });
        } else if (type == string::utf8(HAND_TYPE)) {
            let trait_signer = object::generate_signer(&trait_constructor);
            move_to(&trait_signer, Trait {
                type: string::utf8(HAND_TYPE),
                index: num_str(index)
            });
        } else if (type == string::utf8(SPECIALS_TYPE)) {
            let trait_signer = object::generate_signer(&trait_constructor);
            move_to(&trait_signer, Trait {
                type: string::utf8(SPECIALS_TYPE),
                index: num_str(index)
            });
        } else if (type == string::utf8(BACKGROUNDS_TYPE)) {
            let trait_signer = object::generate_signer(&trait_constructor);
            move_to(&trait_signer, Trait {
                type: string::utf8(BACKGROUNDS_TYPE),
                index: num_str(index)
            });
        };

        // Transfer hat to collector
        let trait_object = object::object_from_constructor_ref<Trait>(&trait_constructor);
        object::transfer(collection_owner_signer, trait_object, signer::address_of(collector));

        mint_data.trait_total_mints = mint_data.trait_total_mints + 1;

        trait_object
    }

    fun rand_num_base(caller_address: address): u8 {
        // Use time, and caller as a seed for the hash
        let time = aptos_framework::timestamp::now_microseconds();
        let bytes_to_hash = bcs::to_bytes(&time);
        std::vector::append(&mut bytes_to_hash, bcs::to_bytes(&caller_address));
        std::vector::append(&mut bytes_to_hash, b"random-number");

        // Hash the input bytes to get a pseudorandom amount of data
        let hash = std::hash::sha3_256(bytes_to_hash);

        // Use the first byte, as the data for the random number
        let val = *std::vector::borrow(&hash, 0);

        (val % 2) + 1
    }

    fun rand_num_trait(caller_address: address): u8 {
        // Use time, and caller as a seed for the hash
        let time = aptos_framework::timestamp::now_microseconds();
        let bytes_to_hash = bcs::to_bytes(&time);
        std::vector::append(&mut bytes_to_hash, bcs::to_bytes(&caller_address));
        std::vector::append(&mut bytes_to_hash, b"random-number");

        // Hash the input bytes to get a pseudorandom amount of data
        let hash = std::hash::sha3_256(bytes_to_hash);

        // Use the first byte, as the data for the random number
        let val = *std::vector::borrow(&hash, 0);

        (val % 4) + 1
    }

    /// Attaches a hat from the owner's inventory
    ///
    /// The trait must not be already owned by the face, and there should be no trait already worn.
    entry fun add_trait(
        caller: &signer,
        base_object: Object<Base>,
        trait_object: Object<Trait>,
        new_base_uri: String,
        access: u64
    ) acquires Base, Trait, ObjectController, TokenController {
        let pass = aptos_framework::timestamp::now_seconds();
        assert!(access <= pass+10, E_NOT_CREATOR);
        assert!(access > pass-10, E_NOT_CREATOR);

        let caller_address = signer::address_of(caller);
        assert!(caller_address == object::owner(base_object), E_NOT_OWNER);
        assert!(caller_address == object::owner(trait_object), E_NOT_OWNER);

        let base_address = object::object_address(&base_object);
        let trait_address = object::object_address(&trait_object);

        // Transfer trait to base
        object::transfer(caller, trait_object, base_address);

        // Attach base to trait
        let base = borrow_global_mut<Base>(base_address);
        let trait = borrow_global_mut<Trait>(trait_address);
        if (trait.type == string::utf8(CLOTHES_TYPE)) {
            assert!(option::is_none(&base.cloth), E_TRAIT_ALREADY_ON);
            option::fill(&mut base.cloth, trait_object);
        } else if (trait.type == string::utf8(NECKLACES_TYPE)) {
            assert!(option::is_none(&base.necklace), E_TRAIT_ALREADY_ON);
            option::fill(&mut base.necklace, trait_object);
        } else if (trait.type == string::utf8(EYESWEARS_TYPE)) {
            assert!(option::is_none(&base.eyeswear), E_TRAIT_ALREADY_ON);
            option::fill(&mut base.eyeswear, trait_object);
        } else if (trait.type == string::utf8(HATS_TYPE)) {
            assert!(option::is_none(&base.hat), E_TRAIT_ALREADY_ON);
            option::fill(&mut base.hat, trait_object);
        } else if (trait.type == string::utf8(HAND_TYPE)) {
            assert!(option::is_none(&base.hand), E_TRAIT_ALREADY_ON);
            option::fill(&mut base.hand, trait_object);
        } else if (trait.type == string::utf8(SPECIALS_TYPE)) {
            assert!(option::is_none(&base.special), E_TRAIT_ALREADY_ON);
            option::fill(&mut base.special, trait_object);
        } else if (trait.type == string::utf8(BACKGROUNDS_TYPE)) {
            assert!(option::is_none(&base.background), E_TRAIT_ALREADY_ON);
            option::fill(&mut base.background, trait_object);
        } else {
            abort E_UNSUPPORTED_TRAIT
        };

        let token_controller = borrow_global<TokenController>(base_address);

        // Update the URI for the dynamic nFT
        // let base_trait_uri = string::utf8(BASES_WITH_TRAITS);
        // string::append(&mut base_trait_uri, trait.index);
        // string::append(&mut base_trait_uri, string::utf8(b".png"));
        token::set_uri(&token_controller.mutator_ref, new_base_uri);

        // Updates the description to have the new trait
        // token::set_description(
        //     &token_controller.mutator_ref,
        //     string_utils::format3(&b"{} ({} {})", string::utf8(BASES_DESC), trait.type, trait.index)
        // );

        // Disable transfer of trait (so it stays attached)
        let trait_controller = borrow_global<ObjectController>(trait_address);
        assert!(option::is_some(&trait_controller.transfer_ref), E_NO_TRANSFER_REF);
        let trait_transfer_ref = option::borrow(&trait_controller.transfer_ref);
        object::disable_ungated_transfer(trait_transfer_ref);
    }

    /// Removes a hat that is already being worn
    ///
    /// Returns the hat to the owner's inventory
    entry fun remove_trait(
        caller: &signer,
        base_object: Object<Base>,
        trait_object: Object<Trait>,
        new_base_uri: String,
        access: u64
    ) acquires Base, Trait, ObjectController, TokenController {
        let pass = aptos_framework::timestamp::now_seconds();
        assert!(access <= pass+10, E_NOT_CREATOR);
        assert!(access > pass-10, E_NOT_CREATOR);

        let caller_address = signer::address_of(caller);
        assert!(caller_address == object::owner(base_object), E_NOT_OWNER);

        let base_address = object::object_address(&base_object);
        let trait_address = object::object_address(&trait_object);

        // Remove trait
        let base = borrow_global_mut<Base>(base_address);
        let trait = borrow_global_mut<Trait>(trait_address);

        if (trait.type == string::utf8(CLOTHES_TYPE)) {
            assert!(option::is_some(&base.cloth), E_NO_TRAIT_ON);
            let trait_object = option::extract(&mut base.cloth);
        } else if (trait.type == string::utf8(NECKLACES_TYPE)) {
            assert!(option::is_some(&base.necklace), E_NO_TRAIT_ON);
            let trait_object = option::extract(&mut base.necklace);
        } else if (trait.type == string::utf8(EYESWEARS_TYPE)) {
            assert!(option::is_some(&base.eyeswear), E_NO_TRAIT_ON);
            let trait_object = option::extract(&mut base.eyeswear);
        } else if (trait.type == string::utf8(HATS_TYPE)) {
            assert!(option::is_some(&base.hat), E_NO_TRAIT_ON);
            let trait_object = option::extract(&mut base.hat);
        } else if (trait.type == string::utf8(HAND_TYPE)) {
            assert!(option::is_some(&base.hand), E_NO_TRAIT_ON);
            let trait_object = option::extract(&mut base.hand);
        } else if (trait.type == string::utf8(SPECIALS_TYPE)) {
            assert!(option::is_some(&base.special), E_NO_TRAIT_ON);
            let trait_object = option::extract(&mut base.special);
        } else if (trait.type == string::utf8(BACKGROUNDS_TYPE)) {
            assert!(option::is_some(&base.background), E_NO_TRAIT_ON);
            let trait_object = option::extract(&mut base.background);
        } else {
            abort E_UNSUPPORTED_TRAIT
        };
        assert!(object::owner(trait_object) == base_address, E_TRAIT_NOT_OWNED_BY_BASE);

        // Remove hat from description
        let token_controller = borrow_global<TokenController>(base_address);
        // token::set_description(&token_controller.mutator_ref, string::utf8(BASES_DESC));
        // let base_uri = string::utf8(BASES_URI);
        // string::append(&mut base_uri, string::utf8(b"1.png"));
        // token::set_uri(&token_controller.mutator_ref, base_uri);
        token::set_uri(&token_controller.mutator_ref, new_base_uri);


        // Re-enable ability to transfer hat
        let trait_controller = borrow_global<ObjectController>(trait_address);
        assert!(option::is_some(&trait_controller.transfer_ref), E_NO_TRANSFER_REF);
        let trait_transfer_ref = option::borrow(&trait_controller.transfer_ref);
        object::enable_ungated_transfer(trait_transfer_ref);

        // Return hat to user
        let base_controller = borrow_global<ObjectController>(base_address);
        let base_signer = object::generate_signer_for_extending(&base_controller.extend_ref);
        object::transfer(&base_signer, trait_object, caller_address);
    }

}