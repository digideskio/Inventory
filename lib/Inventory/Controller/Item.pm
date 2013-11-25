# Abstract: Item Controller for Inventory App
#===============================================================================
#
#         FILE: Inventory/Controller/Item.pm
#
#  DESCRIPTION:
#
#       AUTHOR: Austin Kenny (), aibistin.cionnaith@gmail.com
# ORGANIZATION: Carry On Coding
#      VERSION: 1.0
#      CREATED: 10/21/2013 03:51:18 PM
#===============================================================================
package Inventory::Controller::Item;
use Dancer2;
use Dancer2::FileUtils qw{dirname path path_or_empty};

#------ PREFIX for this route.
my $PREFIX = q{/item};
prefix $PREFIX;

use Template;
use Data::Dump qw/dump/;

#---- Caching

#use Dancer2::Plugin::Cache::CHI;

#check_page_cache; #-- For caching a page response

#------ Locate my Databse Modules
use FindBin;
my $run_dir      = $FindBin::Bin;
my $BASE_DIR     = path("$run_dir/..");
my $INVENTORY_DB = path("$BASE_DIR/sql/inventory.db");
my $IMAGES_DIR   = "item_images";

#------ Inventory Db Item Module
use Inventory::Db::Item;
use Inventory::Form::Item;

#------ Debug
use Log::Any::Adapter qw/Stdout/;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);

#--- My utility files
use MyUtil qw { camelcase_str  full_chomp is_str_alpha  make_str_alpha };
use MyDateUtil qw { format_yyyy_mm_dd_T_hhmmss  };

#------ GLOBALS
use MyConstant qw/$FAIL $NO  $ONE_TO_500 $FIVE_TO_1000 $TEN_TO_10000  $PI $YES/;

my $TYPE         = q{type};
my $LOCATION     = q{location};
my $LENGTH       = q{length};
my $WIDTH        = q{width};
my $HEIGHT       = q{height};
my $DIAMETER     = q{diameter};
my $WEIGHT       = q{weight};
my $PHOTO        = q{photo};
my $EXTERNAL_REF = q{external_ref};
my $COMMENTS     = q{comments};

#--- templates
my $ADD_ITEM_T         = q/add_item/;
my $ADD_ITEM_SUCCESS_T = q/add_item_success/;
my $VIEW_ITEMS_T       = q/view_items/;

#-------------------------------------------------------------------------------
#  Before Processing
#-------------------------------------------------------------------------------
#hook before => sub {
#        forward '/foo/oversee',  { note => 'Hi there' };
#};
#-------------------------------------------------------------------------------
# Some Template Toolkit Housekeeping
#-------------------------------------------------------------------------------
hook before_template_render => sub {
    my $tokens = shift;

    #--- set the base path for template toolkit
    #         $tokens->{uri_base} = request->base->path;
};

=head2  /
    Nothing here, go to view_items.
=cut

get '/' => sub {
    forward '/item/view_items';
};

#-------------------------------------------------------------------------------
#  View Items
#-------------------------------------------------------------------------------

=head2  view_items
    Look at all the items in the inventory.
=cut

get '/view_items' => sub {
    debug("\n Inside view_items");

    #------ Connect to Inventory Database
    my $DbItem = Inventory::Db::Item->new( db_name => $INVENTORY_DB );

    my $items = $DbItem->select_all_items_detail();

    #    debug("Got All Items : " . dump $items);
    my $select_one_item_photo = sub {
        my $photos = $DbItem->select_item_photo(@_);
        return $photos->[0]{rel_location};

    };

    my %template_vars = (
        item_list                  => $items,
        one_photo                  => sub { $select_one_item_photo->(@_) },
        camelcase_str              => sub { camelcase_str(@_) },
        format_yyyy_mm_dd_T_hhmmss => sub { format_yyyy_mm_dd_T_hhmmss(@_) },
        print_time                 => vars->{'time'}
    );

    $DbItem->safe_disconnect();
    template $VIEW_ITEMS_T, \%template_vars;
};

#-------------------------------------------------------------------------------
#  Add Item To Inventory
#-------------------------------------------------------------------------------

=head2 get add_item
    Submit the form to
    add an item to the inventory.
=cut

get '/add_item' => sub {
    debug("\n Inside add_item");
    my ( $types, $locations ) = get_type_and_location_lists();

    my $AdForm = Inventory::Form::Item->new(
        types     => $types,
        locations => $locations,
    );

    my $template_vars = $AdForm->create_form_template();

    debug( 'Got Template Vars For Initial form : '
          . dump( $template_vars->{length} ) );
    template $ADD_ITEM_T, $template_vars;
};

=head2 post add_item
    Add Item to the inventory DB
=cut

post '/add_item' => sub {

    debug("Inside add_item POST:");

    #------ Validate the User Input
    my ($AdForm) = validate_add_item_form(
        {
            type     => params->{$TYPE},
            location => params->{$LOCATION},
            length   => params->{$LENGTH},
            width    => params->{$WIDTH},
            height   => params->{$HEIGHT},
            diameter => params->{$DIAMETER},
            weight   => params->{$WEIGHT},
            photo    => upload($PHOTO),
        }
    );

    #----- Print success page
    if ( $AdForm->is_valid() ) {
        my $new_item_h = insert_item_to_database($AdForm);
        debug(
            'Returned from Insert item with new Item : ' . dump $new_item_h );

        #todo Create Error if fail
        #select last added and show in success page
        #        my $form_data = $AdForm->form_data();
        template $ADD_ITEM_SUCCESS_T,
          {
            new_item                   => $new_item_h,
            bootstrap_validation_state => 'has-success',
            camelcase_str              => sub { camelcase_str(@_) },
            format_yyyy_mm_dd_T_hhmmss =>
              sub { format_yyyy_mm_dd_T_hhmmss(@_) },
            add_item_route => $PREFIX . q{/add_item},
          };
    }
    else {
        #----- or Render the form with the errors
        debug('Form had some errors,  and is being resubmitted!');
        my $template_vars_h = $AdForm->create_form_template();
        $template_vars_h->{return_route} = template $ADD_ITEM_T,
          $template_vars_h;
    }
};

#-------------------------------------------------------------------------------
#                    U S E R      S T U F F
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
#                   C U S T O M E R    S T U F F
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
#                    U S E R      S T U F F
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
#                   C U S T O M E R    S T U F F
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
#  Remove From Items
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
#    Get Data Lists
#-------------------------------------------------------------------------------
sub validate_add_item_form {
    my $params = shift;
    my ( $types, $locations ) = get_type_and_location_lists();

    my $AdForm = Inventory::Form::Item->new(
        {
            type      => $params->{type},
            location  => "      " . $params->{location} . "sss",
            length    => $params->{length},
            width     => $params->{width},
            height    => $params->{height},
            diameter  => $params->{diameter},
            weight    => $params->{weight},
            photo     => $params->{photo},
            types     => $types,
            locations => $locations,
            submitted => $YES,
        }
    );

    $AdForm->validate();
    debug( 'Form validation status is : '
          . ( $AdForm->is_valid() // '<fix this too>' ) );
    return ($AdForm);
}

sub get_type_and_location_lists {
    my $ItemDb    = Inventory::Db::Item->new( db_name => $INVENTORY_DB );
    my $types     = get_types($ItemDb);
    my $locations = get_locations($ItemDb);

    $ItemDb->safe_disconnect();
    return ( $types, $locations );
}

sub get_types {
    my $DbItem = shift;
    my $types = $DbItem->selectall_item_types( { id => 1, name => 1 } );
    return $types;
}

sub get_locations {
    my $DbItem = shift;
    my $locations = $DbItem->selectall_locations( { id => 1, name => 1 } );
    return $locations;
}

#-------------------------------------------------------------------------------
#  Insert Item To Database
#  Return the last Item to be inserted
#-------------------------------------------------------------------------------
sub insert_item_to_database {
    my $AdForm = shift;

    #--- Save(temporarily) the uploaded file with its original name
    my $photo_obj = $AdForm->photo();

    my $DbItem = Inventory::Db::Item->new(
        db_name                      => $INVENTORY_DB,
        origin_filepath_abs          => path( $photo_obj->tempname ),
        destination_base_dir_abs     => $BASE_DIR,
        destination_type_subdir_name => $IMAGES_DIR,
        new_filename                 => $photo_obj->filename,
        dummy_path                   => path( $BASE_DIR . '/' . 'DUMMIES_DOH' ),
    );

    #--- Insert the new item, then return the new item entry.
    #----Get the corresponding photos for this item
    my $new_item_h =
      $DbItem->insert_and_return_item_details(
        $AdForm->get_form_field_values() );

    #--- Insert already committed
    $DbItem->safe_disconnect();

    return $new_item_h;
}

#-------------------------------------------------------------------------------
true;